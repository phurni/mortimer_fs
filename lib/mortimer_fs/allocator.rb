module MortimerFs
  module Allocator
    class << self
      def register(fourcc, klass)
        @handlers ||= {}
        @handlers[fourcc] = klass
      end

      def for(volume, fourcc)
        klass = @handlers[fourcc]
        raise Errno::EFTYPE.new(fourcc.dump) unless klass

        klass.for(volume)
      end
    end
  end
end
