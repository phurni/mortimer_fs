module MortimerFs
  class File
    RDONLY = ::File::RDONLY
    WRONLY = ::File::WRONLY
    RDWR   = ::File::RDWR
    APPEND = ::File::APPEND

    def self.read(volume, inode, size, offset)
      fh = new(volume, inode, flags: RDONLY)
      fh.read(size, offset)
    ensure
      fh.close
    end

    def self.write(volume, inode, buffer, offset)
      fh = new(volume, inode)
      fh.write(buffer, offset, flags: WRONLY)
    ensure
      fh.close
    end

    # flags: O_RDONLY, O_WRONLY, O_RDWR, O_APPEND
    def initialize(volume, inode, flags: RDONLY)
      @volume = volume
      @inode = inode
      @flags = flags
    end

    # TODO: Reimplement with growing buffer without allocation
    def read(size, offset)
      puts "File<#{@inode}>#read(size=#{size}, offset=#{offset})"
      return "" if size == 0 || offset >= self.size

      data_clusters, complete = @inode.data_clusters_for(size, offset)
      return "" if data_clusters.empty?

      if data_clusters.size == 1 && complete
        # Read the one and only cluster into the buffer
        buffer = @volume.read(1, data_clusters.first)
        # Return the requested part
        buffer[offset % @volume.cluster_size, size]
      else
        # Read the first cluster into the buffer
        buffer = @volume.read(1, data_clusters.shift)
        # Remove the unneeded part at the beginning
        buffer.slice!(0, offset % @volume.cluster_size)

        # Keep last cluster for special handling only if no EOF in the requested range
        last_cluster = data_clusters.pop if complete

        # For whole clusters, read them appending to the buffer
        data_clusters.each do |data_cluster|
          buffer << @volume.read(1, data_cluster)
        end

        if last_cluster
          # Read the last cluster into the buffer
          buffer << @volume.read(1, last_cluster)
          # Remove the unneeded part at the end
          buffer.slice!(size..-1)
        end

        buffer
      end
    end

    def write(data, offset)
      puts "File<#{@inode}>#write(data.size=#{data.size}, offset=#{offset})"
      return if data.size == 0

      data_clusters = @inode.ensure_data_clusters_for(data.size, offset)

      if data_clusters.size == 1
        # Read the one and only cluster into the buffer
        buffer = @volume.read(1, data_clusters.first)
        # Replace the part of the buffer with the data
        buffer[offset % @volume.cluster_size, data.size] = data
        # Write it back
        @volume.write(buffer, data_clusters.first)
      else
        # Read the first cluster into the buffer
        buffer = @volume.read(1, data_clusters.first)
        # Replace the part of the content with the beginning of the buffer
        part_size = @volume.cluster_size - (offset % @volume.cluster_size)
        buffer[offset % @volume.cluster_size, part_size] = data[0, part_size]
        # Write it back
        @volume.write(buffer, data_clusters.first)

        # For whole clusters, write them
        data_cursor = part_size
        data_clusters[1..-2].each do |data_cluster|
          @volume.write(data[data_cursor, @volume.cluster_size], data_cluster)
          data_cursor += @volume.cluster_size
        end

        # Read the last cluster into the buffer
        buffer = @volume.read(1, data_clusters.last)
        # Replace the part of the content with the end of the buffer
        buffer[0, data.size - data_cursor] = data[data_cursor..-1]
        # Write it back
        @volume.write(buffer, data_clusters.last)
      end
    
      @inode.size = offset + data.size if offset + data.size > @inode.size
    end

    def size
      @inode.size
    end

    def close
      puts "File<#{@inode}>#close() flags=#{"%08b" % @flags}"
      @inode.write if (@flags & (WRONLY | RDWR | APPEND)) != 0
    end
  end
end
