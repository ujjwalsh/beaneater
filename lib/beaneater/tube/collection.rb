module Beaneater
  class Tubes < PoolCommand
    def initialize(pool)
      @last_used = 'default'
      super
    end

    # @beaneater_connection.tubes.find('tube2')
    # @beaneater_connection.tubes['tube2']
    def find(tube_name)
      Tube.new(self.pool, tube_name)
    end
    alias_method :[], :find

    # @beaneater_connection.tubes.reserve { |job| process(job) }
    def reserve(timeout=nil, &block)
      res = transmit_to_rand(timeout ? "reserve-with-timeout #{timeout}" : 'reserve')
      job = Job.new(res)
      block.call(job) if block_given?
      job
    end

    # Uses specified tube
    def use(tube)
      return tube if @last_used == tube
      res = transmit_to_all "use #{tube}"
      @last_used = tube
    rescue BadFormatError
      raise InvalidTubeName, "Tube cannot be named '#{tube}'"
    end

    # @beaneater_connection.tubes.all
    def all
      transmit_to_rand('list-tubes')[:body].map { |tube_name| Tube.new(self.pool, tube_name) }
    end

    # @beaneater_connection.tubes.used
    def used
      Tube.new(self.pool, transmit_to_rand('list-tube-used')[:id])
    end

    # @beaneater_connection.tubes.watched
    def watched
      transmit_to_rand('list-tubes-watched')[:body].map { |tube_name| Tube.new(self.pool, tube_name) }
    end

    # @beaneater_connection.tubes.watch('foo', 'bar')
    def watch(*names)
      names.each do |t|
        transmit_to_all "watch #{t}"
      end
    rescue BadFormatError => ex
      raise InvalidTubeName, "Tube in '#{ex.cmd}' is invalid!"
    end

    # @beaneater_connection.tubes.watch!('foo', 'bar')
    def watch!(*tube_names)
      old_tubes = watched.map(&:name) - tube_names.map(&:to_s)
      watch(*tube_names)
      ignore(*old_tubes)
    end

    # @beaneater_connection.tubes.ignore('foo', 'bar')
    def ignore(*names)
      names.each do |w|
        transmit_to_all "ignore #{w}"
      end
    end
  end # Tubes
end # Beaneater