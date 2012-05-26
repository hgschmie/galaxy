require 'fileutils'
require 'logger'
require 'ostruct'
require 'resolv'
require 'socket'
require 'stringio'
require 'yaml'

require 'rubygems'
require 'galaxy/agent_remote_api'
require 'galaxy/config'
require 'galaxy/controller'
require 'galaxy/db'
require 'galaxy/deployer'
require 'galaxy/fetcher'
require 'galaxy/log'
require 'galaxy/properties'
require 'galaxy/repository'
require 'galaxy/software'
require 'galaxy/starter'
require 'galaxy/transport'
require 'galaxy/version'
require 'galaxy/versioning'
require 'galaxy/slotinfo'

module Galaxy
  class Agent
    attr_reader :agent_id, :agent_group, :machine, :config, :locked, :logger, :gonsole_url
    attr_accessor :starter, :fetcher, :deployer, :db, :slot_info

    include Galaxy::AgentRemoteApi

    def initialize agent_id, agent_group, url, machine, announcements_url, repository_base, deploy_dir,
      data_dir, binaries_base, http_user, http_password, slot_environment, log, log_level, announce_interval
      @drb_url = url
      @agent_id = agent_id
      @agent_group = agent_group
      @machine = machine
      @http_user = http_user
      @http_password = http_password
      @repository_base = repository_base
      @binaries_base = binaries_base

      @logger = Galaxy::Log::Glogger.new log
      @logger.log.level = log_level

      @slot_environment = load_slot_environment slot_environment

      @lock = OpenStruct.new(:owner => nil, :count => 0, :mutex => Mutex.new)

      # set up announcements
      @gonsole_url = announcements_url
      @announcer = Galaxy::Transport.locate announcements_url, @logger

      # Create missing folders if they don't already exist. This needs
      # to be done here, so that in case that the agent changes the user to run as
      # it is done as the new user, not as the old (root) user.
      FileUtils.mkdir_p(deploy_dir) unless File.exists? deploy_dir
      FileUtils.mkdir_p(data_dir) unless File.exists? data_dir

      @announce_interval = announce_interval
      @repository = Galaxy::Repository.new repository_base, @logger
      @db = Galaxy::DB.new data_dir
      @slot_info = Galaxy::SlotInfo.new @db, repository_base, binaries_base, @logger, @machine, @agent_id, @agent_group, @slot_environment
      @deployer = Galaxy::Deployer.new repository_base, binaries_base, deploy_dir, @logger, @slot_info
      @fetcher = Galaxy::Fetcher.new binaries_base, @http_user, @http_password, @logger
      @starter = Galaxy::Starter.new @logger, @db

      if RUBY_PLATFORM =~ /\w+-(\D+)/
        @os = $1
        @logger.debug "Detected OS: #{@os}"
      end

      @logger.debug "Detected machine: #{@machine}"

      current_deployment = current_deployment_number
      @config = read_config current_deployment

      # Make sure that the slot_info file is current.
      @slot_info.update @config.config_path, @deployer.core_base_for(current_deployment)

      Galaxy::Transport.publish url, self, @logger
      announce
      sync_state!

      @thread = Thread.start do
        loop { sleep @announce_interval; announce }
      end
    end

    #
    # Loads the slot environment file for this
    # deployment. This is stored alongside the 
    # actual slot data for later use.
    #
    def load_slot_environment slot_environment
      unless slot_environment.nil? 
        begin
          File.open slot_environment, "r" do |f|
            return YAML.load(f.read)
          end
        rescue Errno::ENOENT
        end
      end
      return {}
    end

    def lock
      @lock.mutex.synchronize do
        raise "Agent is locked performing another operation" unless @lock.owner.nil? || @lock.owner == Thread.current

        @lock.owner = Thread.current if @lock.owner.nil?

        @logger.debug "Locking from #{caller[2]}" if @lock.count == 0
        @lock.count += 1
      end
    end

    def unlock
      @lock.mutex.synchronize do
        raise "Lock not owned by current thread" unless @lock.owner.nil? || @lock.owner == Thread.current
        @lock.count -= 1
        @lock.owner = nil if @lock.count == 0

        @logger.debug "Unlocking from #{caller[2]}" if @lock.count == 0
      end
    end

    def status
      OpenStruct.new(
        :agent_id => @agent_id,
        :agent_group => @agent_group,
        :url => @drb_url,
        :os => @os,
        :machine => @machine,
        :core_type => config.core_type,
        :config_path => config.config_path,
        :build => config.build,
        :status => @starter.status(config.core_base),
        :last_start_time => config.last_start_time,
        :agent_status => 'online',
        :galaxy_version => Galaxy::Version,
        :slot_info => @slot_info.get_slot_info
      )
    end

    def announce
      begin
        res = @announcer.announce status
        return res
      rescue Exception => e
        error_reason = "Unable to communicate with console, #{e.message}"
        @logger.warn "Unable to communicate with console, #{e.message}"
        @logger.warn e
      end
    end

    def read_config deployment_number
      config = nil
      deployment_number = deployment_number.to_s
      data = @db[deployment_number]
      unless data.nil?
        begin
          config = YAML.load data
          unless config.is_a? OpenStruct
            config = nil
            raise "Expecting serialized OpenStruct"
          end
        rescue Exception => e
          @logger.warn "Error reading deployment descriptor: #{@db.file_for(deployment_number)}: #{e}"
        end
      end
      config ||= OpenStruct.new
      # Ensure autostart=true for pre-2.5 deployments
      if config.auto_start.nil?
        config.auto_start = true
      end
      config
    end

    def write_config deployment_number, config
      deployment_number = deployment_number.to_s
      @db[deployment_number] = YAML.dump config
    end

    def current_deployment_number
      @db['deployment'] ||= "0"
      @db['deployment'].to_i
    end

    def current_deployment_number= deployment_number
      deployment_number = deployment_number.to_s
      @db['deployment'] = deployment_number
      @config = read_config deployment_number
    end

    # private
    def sync_state!
      lock

      begin
        if @config
          # Get the status from the core
          status = @starter.status @config.core_base
          @config.state = status
          write_config current_deployment_number, @config
        end
      ensure
        unlock
      end
    end

    # Stop the agent
    def shutdown
      @starter.stop! config.core_base if config
      @thread.kill
      Galaxy::Transport.unpublish @drb_url
    end

    # Wait for the agent to finish
    def join
      @thread.join
    end

    # args: agent_url => URL that this agent is listening to
    #       agent_group/agent_id  to uniquely identify this agent
    #     console_url => URL of the console
    #     repository => base of url to repository
    #     binaries => base of url=l to binary repository
    #     deploy_dir => /path/to/deployment
    #     data_dir => /path/to/agent/data/storage
    #     log => /path/to/log || STDOUT || STDERR || SYSLOG
    #     url => url to listen on
    def Agent.start args
      agent_url = args[:agent_url] || "druby://localhost:4441"
      agent_url = "druby://#{agent_url}" unless agent_url.match("^http://") || agent_url.match("^druby://") # defaults to drb
      agent_url = "#{agent_url}:4441" unless agent_url.match ":[0-9]+$"

      # default console to http/4442 unless specified
      console_url = args[:console] || "http://localhost:4442"
      console_url = "http://" + console_url unless console_url.match("^http://") || console_url.match("^druby://")
      console_url += ":4442" unless console_url.match ":[0-9]+$"

      if args[:machine]
        machine = args[:machine]
      else
        machine_file = args[:machine_file] || Galaxy::Config::DEFAULT_MACHINE_FILE
        if File.exists? machine_file
          File.open machine_file, "r" do |f|
            machine = f.read.chomp
          end
        else
          machine = Socket.gethostname
        end
      end

      repository = args[:repository] || "/tmp/galaxy-agent-properties"
      deploy_dir = args[:deploy_dir] || "/tmp/galaxy-agent-deploy"
      data_dir = args[:data_dir] || "/tmp/galaxy-agent-data"
      binaries = args[:binaries] || "http://localhost:8000"
      log = args[:log] || "STDOUT"
      log_level = args[:log_level] || Logger::INFO
      announce_interval = args[:announce_interval] || 60

      agent = Agent.new args[:agent_id],
                        args[:agent_group],
                        agent_url,
                        machine,
                        console_url,
                        repository,
                        deploy_dir,
                        data_dir,
                        binaries,
                        args[:http_user],
                        args[:http_password],
                        args[:slot_environment],
                        log,
                        log_level,
                        announce_interval

      agent
    end

    private :initialize, :sync_state!, :config
  end

end
