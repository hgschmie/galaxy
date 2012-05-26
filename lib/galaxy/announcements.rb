require 'net/http'
require 'uri'
require 'yaml'
require 'ostruct'
require 'logger'

require 'rubygems'
require 'thin'
require 'json'

module Galaxy
  module HTTPUtils
    def url_escape(string)
      string.gsub(/([^ a-zA-Z0-9_.-]+)/n) do
        '%' + $1.unpack('H2' * $1.size).join('%').upcase
      end.tr(' ', '+')
    end

    def url_unescape(string)
      string.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2})+)/n) do
        [$1.delete('%')].pack('H*')
      end
    end
  end

  class HTTPServer
    def initialize(url, console, callbacks=nil, log=nil)
      @log = log || Logger.new(STDOUT)
      
      app = Rack::URLMap.new(
        '/' => ReceiveAnnouncement.new(console),
        '/status' => AnnouncementStatus.new)
      
      # Create server
      begin
        @server = Thin::Server.new('0.0.0.0', get_port(url), app)
      rescue Exception => err
        msg = "HTTP server initialization error: #{err}"
        @log.error msg
        raise IOError, msg
      end

      # Actually start the server
      @thread = Thread.new do
        begin
          @server.start!
        rescue Exception => err
          msg = "HTTP server start error: #{err}"
          @log.error msg
          raise msg
        end
      end
      sleep 1
    end

    # parse the port from the given url string
    def get_port(url)
      begin
        last = url.count(':')
        raise "malformed url: '#{url}'." if last==0 || last>2
        port = url.split(':')[last].to_i
      rescue Exception => err
        msg = "Problem parsing port for string '#{url}': error = #{err}"
        @log.error msg
        raise msg
      end
      port
    end

    def shutdown
      if @server
        @server.stop!
        @thread.join
        @server = @thread = nil
      end
    end
  end

  # POST handler that receives announcements and calls the callback function with the data payload
  class ReceiveAnnouncement
    ANNOUNCEMENT_RESPONSE_TEXT = 'Announcement received.'
    def initialize(console)
      @console = console
    end
  
    def call(env)
      response = ""
      if env['REQUEST_METHOD'] == 'POST'
        @console.process_post(YAML::load(env['rack.input'].read))
        response << ANNOUNCEMENT_RESPONSE_TEXT
      elsif env['REQUEST_METHOD'] == 'GET'
        response << @console.process_get(env['REQUEST_PATH'])
      end
      [ 
        200, 
        { 'Content-Type' => 'text/plain; charset=utf-8', 'Connection' => 'close' }, 
        [response] 
      ]
    end
  end

  # optional GET response for querying the server status
  class AnnouncementStatus
    def call(env)
      if env['REQUEST_METHOD'] == 'GET'
        time = Time.now
        response = ""
        response << "<html><body>"
        response << "<h2>Announcement Status</h2><br /><br />"
        response << time.strftime("%Y%m%d-%H:%M:%S") + sprintf(".%06d", time.usec)
        response << "</body></html>"
        [
          200,
          { 'Content-Type' => 'text/plain; charset=utf-8', 'Connection' => 'close' },
          [response]
        ]
      end
    end
  end

end

# HTTP client library.
# Used by the galaxy agent to send announcements to the server.
# Used by the command line client to query the gonsole over HTTP.
class HTTPAnnouncementSender
  include Galaxy::HTTPUtils

  def initialize(url, log = nil)
      # eg: 'http://encomium.company.com:4440'
      @uri = URI.parse(url)
      @log = log
  end

  # Announce an agent to a gonsole
  # agent is an OpenStruct defining the state of the agent.
  def announce(agent)
      begin
          # POST
          Net::HTTP.start(@uri.host, @uri.port) do |http|
              headers = {'Content-Type' => 'text/plain; charset=utf-8', 'Connection' => 'close'}
              put_data = agent.to_yaml
              start_time = Time.now
              response = http.send_request('POST', @uri.request_uri, put_data, headers)
              @log.debug "Announcement #{put_data} sent, response time for #{agent.agent_id}/#{agent.agent_group} = #{Time.now-start_time}" if @log
              #puts "Response = #{response.code} #{response.message}: #{response.body}"
              response.body
          end
      rescue Exception => e
          @log.warn "Client side error: #{e}" if @log
      end
  end

  # Retrieve a list of agents matching a giving filter
  # args is a hash filter (cf Galaxy::Filter).
  def agents(args)
      # Convert filter string ({:set=>:all}) to URI string (/set=all)
      # XXX Built-in method to do that?
      filter = ""
      args.each do |key, value|
          filter += url_escape(key.to_s) + "=" + url_escape(value.to_s) + "&"
      end
      filter.chomp!("&")

      begin
          Net::HTTP.start(@uri.host, @uri.port) do |http|
              headers = {'Content-Type' => 'text/plain; charset=utf-8', 'Connection' => 'close'}
              start_time = Time.now
              response = http.send_request('GET', @uri.request_uri + filter, headers)
              @log.debug "Announcement sent, response time: #{Time.now-start_time}" if @log
              return JSON.parse(response.body).collect { |x| OpenStruct.new(x) }
          end
      rescue Exception => e
          # If the json gem is not loaded, we will log the issue here.
          @log.warn "Client side error: #{e}" if @log
          return []
      end
  end

  # :nodoc:
  # Compatibility with the DRb galaxy client.
  # XXX Should go away (overhead).
  def log(* args)
      nil
  end
end


################################################################################################
#
# sample MAIN
#

# example callback for action upon receiving an announcement
def on_announcement(ann)
  puts "...received announcement: #{ann.inspect}"
end

# Initialize and POST to server
if $0 == __FILE__ then
  # start server
  url = 'http://encomium.company.com:4440'
  Galaxy::HTTPAnnouncementReceiver.new(url, lambda { |a| on_announcement(a) })
  announcer = HTTPAnnouncementSender.new(url)

  # periodically, send stuff to it
  loop do
    begin
      announcer.announce(OpenStruct.new(:foo=>"bar", :rand => rand(100), :item => "eggs"))

      puts "server running..."
      sleep 15
    rescue Exception => err
      STDERR.puts "* #{err}"
      exit(1)
    end
  end
end
