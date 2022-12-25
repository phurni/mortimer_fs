module MortimerFs
  module Inode
    class << self
      def register(fourcc, klass)
        @handlers ||= {}
        @handlers[fourcc] = klass
      end

      def for(volume, inode)
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

      def make(volume, stat_hash)
        fourcc = volume.prefered_inode_fourcc
        klass = @handlers[fourcc]
        raise Errno::EFTYPE.new(fourcc.dump) unless klass

        klass.make(volume, stat_hash)
      end
    end
  end
end
