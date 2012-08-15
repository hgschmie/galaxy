require 'socket'
require 'json'

module Galaxy
  class ConsoleObserver

    def initialize
      load_config
      @socket = UDPSocket.new
    end

    def load_config
      @observer = File.open('/etc/galaxy.conf') do |file|
        file.read.match /galaxy.console.observer:\s*([^\n]*)/
        $1
      end

      @host, @port = @observer.split(':')
    end

    def changed(key, value)
      @socket.send(
        {key => value}.to_json,
        0,
        @host,
        @port
      )
    end

  end
end