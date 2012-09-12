require 'socket'
require 'json'
require 'ostruct'

module Galaxy
  class ConsoleObserver

    def initialize(observer_host = nil)
      @observer_host = observer_host
      @host, @port = @observer_host.split(':') unless @observer_host.nil?

      @socket = UDPSocket.new
    end

    def changed(key, value = nil)
      unless @observer_host.nil?
        if value.nil?
          value = OpenStruct.new
          value.timestamp = Time.now.to_s
        end

        @socket.send(
          {key => to_hash(value) }.to_json,
          0,
          @host,
          @port
        )
      end
    end

    def to_hash(obj)
      hash = nil
      if obj.respond_to?(marshal_dump)
        dump = obj.marshal_dump

        if (obj.class == OpenStruct)
          dump[:slot_info] = obj[:slot_info].marshal_dump if obj.has_key? :slot_info
        end

        dump
      else
        obj # good luck...
      end
    end
  end
end
