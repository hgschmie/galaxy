require 'thread'

module Galaxy
  class DB
    def initialize path
      @lock = Mutex.new
      @path = path
      Dir.mkdir @path rescue nil
    end

    def delete_at key
      @lock.synchronize { FileUtils.rm_f file_for(key) }
    end

    def []= key, value
      @lock.synchronize do
        File.open(file_for(key), "w") { |f| f.write(value) }
      end
    end

    def [] key
      @lock.synchronize do
        result = nil
        begin
          File.open(file_for(key), "r") { |f| result = f.read }
        rescue Errno::ENOENT
        end

        return result
      end
    end

    def file_for key
      File.join(@path, key)
    end
  end
end
