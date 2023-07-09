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

      def open(volume, inode, flags: File::RDONLY)
        klass = @handlers[File.read(volume, inode, 4, 0)] || volume.directory_handler
        raise Errno::EFTYPE.new(fourcc.dump) unless klass

        dir = klass.new(volume, inode, flags: flags)
        if block_given?
          begin
            yield dir
          ensure
            dir.close
          end
        else
          dir
        end
      end
    end
  end
end
