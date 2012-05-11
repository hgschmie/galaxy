require 'timeout'

module Galaxy
  module AgentUtils
  def ping_agent agent
    Timeout::timeout(5) { agent.proxy.status }
  end

  module_function :ping_agent
  end
end
