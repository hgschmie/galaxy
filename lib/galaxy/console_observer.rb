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
      
      return if @observer.nil?
      @host, @port = @observer.split(':')
    end

    def changed(key, value)
      unless @observer.nil?
        @socket.send(
          {key => to_hash(value) }.to_json,
          0,
          @host,
          @port
        )
      end
    end

    def to_hash(obj)
      obj = obj.marshal_dump
      obj[:slot_info] = obj[:slot_info].marshal_dump if obj.has_key? :slot_info
      obj
    end

  end
end