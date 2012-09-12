require 'ostruct'
require 'yaml'

module Galaxy
  class SlotInfo
    def initialize (db, repository_base, binaries_base, log, machine, agent_id, agent_group, slot_environment = nil, tmp_dir = nil, persistent_dir = nil)
      @db = db
      @repository_base = repository_base
      @binaries_base = binaries_base
      @log = log
      @machine = machine
      @agent_id = agent_id
      @agent_group = agent_group
      @slot_environment = slot_environment
      @tmp_dir = tmp_dir
      @persistent_dir = persistent_dir
    end

    # Writes the current state of the world into the
    # slot_info file.
    def update (config_path, core_base, config_uri = nil, binaries_uri = nil)
      slot_info = OpenStruct.new(:base =>           core_base,
                                 :config_path =>    config_path,
                                 :repository =>     config_uri || @repository_base,
                                 :binaries =>       binaries_uri || @binaries_base,
                                 :machine =>        @machine,
                                 :agent_id =>       @agent_id,
                                 :agent_group =>    @agent_group,
                                 :tmp_dir =>        @tmp_dir,
                                 :persistent_dir => @persistent_dir,
                                 :env =>            @slot_environment)

      @log.debug "Slot Info now #{slot_info}"
      @db['slot_info'] = YAML.dump slot_info
    end

    def get_file_name
      @db.file_for('slot_info')
    end

    def get_slot_info
      YAML.load(@db['slot_info'])
    end
  end
end



