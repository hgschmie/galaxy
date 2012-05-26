require 'thread'

class CountingSemaphore

  def initialize(initvalue = 0)
    @counter = initvalue
    @waiting_list = []
  end

  def wait
    s = Thread.exclusive {
      @counter -= 1
      if @counter < 0
        @waiting_list.push(Thread.current)
        true
      else
        false
      end
    }
    Thread.stop if s
    self
  end

  def signal
    t = Thread.exclusive {
      @counter += 1
      if @counter <= 0
        @waiting_list.shift
      end
    }
    t.wakeup if t
    self
  end

  def exclusive
    wait
    yield
  ensure
    signal
  end

end

class ThreadGroup

  def join
    list.each { |t| t.join }
  end

  def <<(thread)
    add thread
  end

  def kill
    list.each { |t| t.kill }
  end

end

# execute in parallel with up to thread_count threads at once
class Array
  def parallelize(thread_count = 100)
    sem = CountingSemaphore.new(thread_count ? thread_count : 100)
    results = []
    threads = ThreadGroup.new

    each_with_index do |item, i|
      sem.wait
      threads << Thread.new do
        begin
          yield item
        ensure
          sem.signal
        end
      end
    end

    threads.join
    results
  end
end
