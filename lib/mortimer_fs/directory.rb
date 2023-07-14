module MortimerFs
  module Directory
    class << self
      def register(fourcc, klass)
        @handlers ||= {}
        @handlers[fourcc] = klass
      end

      def for(fourcc)
        @handlers[fourcc] or raise Errno::EFTYPE.new(fourcc.dump)
      end
    end
  end
end
