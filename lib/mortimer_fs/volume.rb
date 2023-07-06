module MortimerFs
  class Volume
    SUPERBLOCK_SIZE = 256

    attr_reader :cluster_size, :root_inode_number, :total_cluster_count
    attr_reader :preferred_inode_fourcc, :preferred_directory_fourcc
    attr_reader :inode_allocator, :data_allocator

    def initialize(device)
      @device = device
      init_from_superblock
    end

    def read(cluster_count, cluster_number)
      @device.sysseek(cluster_number * @cluster_size)
      @device.sysread(cluster_count * @cluster_size)
    end

    def write(buffer, cluster_number)
      raise Errno::EDOM.new if buffer.size % @cluster_size != 0
      @device.sysseek(cluster_number * @cluster_size)
      @device.syswrite(buffer)
    end

    protected

    SUPERBLOCK_FOURCC = "MoFS"
    SUPERBLOCK_PACK_FORMAT = "a4La4a4LLLLLLa4a4a16Z192"

    def init_from_superblock
      @device.sysseek(0)
      @superblock_buffer = @device.sysread(SUPERBLOCK_SIZE) # TODO: Ask the device for the block_size to respect its block behaviour

      superblock_fourcc, _, @preferred_inode_fourcc, @preferred_directory_fourcc, @cluster_size, _, @total_cluster_count, _, @root_inode_number, _, inode_allocator_fourcc, data_allocator_fourcc, volume_uuid, volume_name = @superblock_buffer.unpack(SUPERBLOCK_PACK_FORMAT)
      raise Errno::EILSEQ.new(superblock_fourcc.dump) if superblock_fourcc != SUPERBLOCK_FOURCC

      @inode_allocator = Allocator.for(self, inode_allocator_fourcc)
      @data_allocator = Allocator.for(self, data_allocator_fourcc)
    end
  end
end
