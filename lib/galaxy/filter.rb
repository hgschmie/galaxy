module Galaxy
  module Filter
    def self.new args
      filters = []

      case args[:set]
      when :all, "all"
        filters << lambda { |a| true }
      when :none, "none"
        filters << lambda { |a| false }
      when :empty, "empty"
        filters << lambda { |a| a.config_path.nil? }
      when :taken, "taken"
        filters << lambda { |a| a.config_path }
      end

      if args[:env] || args[:version] || args[:type]
        env = args[:env] || "[^/]+"
        version = args[:version] || "[^/]+"
        type = args[:type] || ".+"

        filters << lambda { |a| a.config_path =~ %r!^/#{env}/#{version}/#{type}$! }
      end
      
      if args[:agent_id]
        filters << lambda { |a| a.agent_id == args[:agent_id] }
      end
      
      if args[:agent_group]
        filters << lambda { |a| a.agent_group == args[:agent_group] }
      end
      
      if args[:machine]
        filters << lambda { |a| a.machine == args[:machine] }
      end
      
      if args[:state]
        filters << lambda { |a| a.status == args[:state] }
      end
      
      if args[:agent_state]
        filters << lambda { |a| a.agent_status == args[:agent_state] }
      end

      lambda do |a|
        filters.inject(true) { |result, filter| result && filter.call(a) }
      end
    end
  end
end
