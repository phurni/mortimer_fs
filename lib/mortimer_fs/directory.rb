module MortimerFs
  module Directory
    class << self
      def register(fourcc, klass)
        @handlers ||= {}
        @handlers[fourcc] = klass
      end

      def open(volume, inode, flags: File::RDONLY)
        fourcc = File.read(volume, inode, 4, 0)
        fourcc = volume.preferred_directory_fourcc if fourcc.empty?

        klass = @handlers[fourcc]
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
