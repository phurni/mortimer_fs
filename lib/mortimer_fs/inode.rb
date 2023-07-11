module MortimerFs
  module Inode
    class << self
      def register(fourcc, klass)
        @handlers ||= {}
        @handlers[fourcc] = klass
      end

      def for(fourcc)
        @handlers[fourcc] or raise Errno::EFTYPE.new(fourcc.dump)
      end

      def from(volume, inode)
        inode_content = volume.read(1, inode)
        fourcc = inode_content[0..3]
        klass = @handlers[fourcc]
        raise Errno::EFTYPE.new(fourcc.dump) unless klass

        handler = klass.new(volume, inode, inode_content)
        if block_given?
          yield handler
        else
          handler
        end
      end
    end
  end
end
