module MortimerFs
  class Volume
    attr_reader :cluster_size, :root_inode_number
    attr_reader :preferred_inode_fourcc, :preferred_directory_fourcc

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

    # Returns an array of allocated cluster numbers
    def allocate(cluster_count)
      # No allocation scheme yet!
      # We simply keep the last cluster number given and give away the next ones.
      # There's no freeing thus the volume may fill to max very quickly.
      raise Errno::ENOSPC if @first_free_cluster + cluster_count > @total_cluster_count

      previous_first_free_cluster = @first_free_cluster
      @first_free_cluster += cluster_count

      update_first_free_cluster
      (previous_first_free_cluster...@first_free_cluster).to_a
    end

    # Frees the passed clusters
    def free(clusters)
    end

    protected

    SUPERBLOCK_FOURCC = "MoFS"
    SUPERBLOCK_SIZE = 256
    SUPERBLOCK_PACK_FORMAT = "a4La4a4LLLLLLLLa16Z192"

    def init_from_superblock
      @device.sysseek(0)
      @superblock_buffer = @device.sysread(512) # TODO: Ask the device for the block_size to respect its block behaviour

      superblock_fourcc, _, @preferred_inode_fourcc, @preferred_directory_fourcc, @cluster_size, _, @total_cluster_count, _, @root_inode_number, _, _, _, volume_uuid, volume_name = @superblock_buffer.unpack(SUPERBLOCK_PACK_FORMAT)
      raise Errno::EILSEQ.new(superblock_fourcc.dump) if superblock_fourcc != SUPERBLOCK_FOURCC

      # Here until we have a real allocation scheme
      @first_free_cluster = @superblock_buffer[SUPERBLOCK_SIZE, 4].unpack1("L")
    end

    def update_first_free_cluster
      @superblock_buffer[SUPERBLOCK_SIZE, 4] = [@first_free_cluster].pack("L")
      @device.sysseek(0)
      @device.syswrite(@superblock_buffer)
    end
  end
end
