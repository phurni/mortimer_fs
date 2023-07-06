module MortimerFs
  module Inode
    class ChainedInode
      FOURCC = "MoI0"

      INODE_HEAD_SIZE = 64
      INODE_HEAD_PACK_FORMAT = "a4LLSSLLQQQQQ"

      INODE_CHAIN_FOURCC = "MoI@"
      INODE_CHAIN_METADATA_SIZE = 4+4
      INODE_CHAIN_CLUSTER_NUMBER_SIZE = 4

      FTYPE_FILE    = 1
      FTYPE_DIR     = 2
      FTYPE_SYMLINK = 4

      FTYPE_SYMBOL_FOR = {FTYPE_FILE => :file, FTYPE_DIR => :directory, FTYPE_SYMLINK => :symlink}
      FTYPE_VALUE_FOR  = FTYPE_SYMBOL_FOR.invert

      @@stat_attribute_names = [:type, :mode, :uid, :gid, :ino, :size, :ctime, :mtime, :atime]
      attr_accessor *(@@stat_attribute_names - [:type, :ino])

      # Define hand made stat accessors to meet our internals
      def ino
        @head_inode
      end
      def type
        FTYPE_SYMBOL_FOR[@type]
      end

      def stat_hash
        @@stat_attribute_names.each_with_object({}) {|name, hash| hash[name] = send(name) }
      end

      # Returns an inode number, not an inode object
      def self.make(volume, stat_hash)
        head_inode = volume.inode_allocator.allocate(1).first

        head_inode_content = Array.new(volume.cluster_size, 0).pack("c*")
        head_inode_content[0, INODE_HEAD_SIZE] = [FOURCC, 0, 0, FTYPE_VALUE_FOR[stat_hash[:type]], stat_hash[:mode], stat_hash[:uid], stat_hash[:gid], stat_hash[:size], stat_hash[:ctime], stat_hash[:mtime], stat_hash[:atime], 0].pack(INODE_HEAD_PACK_FORMAT)
        volume.write(head_inode_content, head_inode)

        head_inode
      end

      def initialize(volume, head_inode, head_inode_content)
        @volume = volume
        @cluster_numbers_count_per_inode = (@volume.cluster_size - INODE_CHAIN_METADATA_SIZE) / INODE_CHAIN_CLUSTER_NUMBER_SIZE

        @head_inode = head_inode
        @head_inode_content = head_inode_content

        _, @first_inode_of_chain, _, @type, @mode, @uid, @gid, @size, @ctime, @mtime, @atime = @head_inode_content[0, INODE_HEAD_SIZE].unpack(INODE_HEAD_PACK_FORMAT)
      end

      def write
        puts "ChainedInode<#{@head_inode}>#write() @first_inode_of_chain=#{@first_inode_of_chain}"
        @head_inode_content[0, INODE_HEAD_SIZE] = [FOURCC, @first_inode_of_chain, 0, @type, @mode, @uid, @gid, @size, @ctime, @mtime, @atime, 0].pack(INODE_HEAD_PACK_FORMAT)
        @volume.write(@head_inode_content, @head_inode)
      end

      def allocated_cluster_count
        inode_chain.lazy.reduce(0) {|memo, (buffer, _)| memo + extract_data_cluster_numbers(buffer).lazy.take_while {|number| number != 0 }.count }
      end

      def data_clusters_for(size, offset)
        puts "ChainedInode<#{@head_inode}>#data_clusters_for(size=#{size}, offset=#{offset}) @first_inode_of_chain=#{@first_inode_of_chain}"
        starting_inode_index = offset_to_inode_index(offset)
        ending_inode_index = offset_to_inode_index(offset + size - 1)

        # Move just before the starting_inode_index. If we can't reach, return telling there's no data clusters
        inode_enumerator = inode_chain
        starting_inode_index.times { inode_enumerator.next } rescue (return [[], false])

        # Read all the required inodes, accumulating data cluster numbers. Track if we reached the ending_inode_index
        data_clusters = []
        complete = starting_inode_index.upto(ending_inode_index) do
          buffer, _ = inode_enumerator.next rescue break
          data_clusters.concat(extract_data_cluster_numbers(buffer))
        end

        # Remove unused ending data clusters only if we have reached the ending_inode_index
        # (Do it before processing the one from the beginning, so that the offset computing is easy (modulo))
        if complete
          cluster_count_to_discard = @cluster_numbers_count_per_inode - offset_to_inode_cluster_number_index(offset + size - 1) - 1
          data_clusters.slice!(-cluster_count_to_discard..-1)
        end

        # Remove unused beginning data clusters
        data_clusters.slice!(0, offset_to_inode_cluster_number_index(offset))

        # Remove all zero data clusters the may be at the end
        if index_of_first_unallocated_cluster = data_clusters.index(0)
          data_clusters.slice!(index_of_first_unallocated_cluster..-1)
        end

        puts "ChainedInode<#{@head_inode}>#data_clusters_for() => complete=#{!!complete} clusters=#{data_clusters.inspect}"
        [data_clusters, complete]
      end

      # TODO: This is a completely naive implementation that goes through the inode chain 3 times! Refactor it.
      def ensure_data_clusters_for(size, offset)
        puts "ChainedInode<#{@head_inode}>#ensure_data_clusters_for(size=#{size}, offset=#{offset}) @first_inode_of_chain=#{@first_inode_of_chain}"

        allocated_data_cluster_count = allocated_cluster_count
        target_data_cluster_count = ((offset + size) / @volume.cluster_size.to_f).ceil

        return data_clusters_for(size, offset).first if allocated_data_cluster_count >= target_data_cluster_count

        ending_inode_index = offset_to_inode_index(offset + size - 1)
        buffer, current_inode_number = @head_inode_content, @head_inode

        # Move to the ending_inode_index inode
        inode_enumerator = inode_chain
        stopped_inode_index = -1
        0.upto(ending_inode_index) do |current_inode_index|
          buffer, current_inode_number = inode_enumerator.next rescue break
          stopped_inode_index = current_inode_index
        end

        # Allocate the missing data clusters
        new_data_clusters = @volume.data_allocator.allocate(target_data_cluster_count - allocated_data_cluster_count)

        # Fill to the max the current inode only if we already have an data cluster inode
        inode_last_cluster_index = extract_data_cluster_numbers(buffer).index(0)
        if inode_last_cluster_index && stopped_inode_index != -1
          new_data_clusters_for_current_inode = new_data_clusters.slice!(0, @cluster_numbers_count_per_inode - inode_last_cluster_index)
          buffer[INODE_CHAIN_METADATA_SIZE + inode_last_cluster_index*4, new_data_clusters_for_current_inode.size*4] = new_data_clusters_for_current_inode.pack("L*")

          # write the inode cluster
          @volume.write(buffer, current_inode_number)
        end

        if stopped_inode_index < ending_inode_index
          # There are missing inodes
          # allocate the missing inode cluster count
          new_inode_clusters = @volume.inode_allocator.allocate(ending_inode_index - stopped_inode_index)

          # link the last inode with the next new one
          buffer[4..7] = [new_inode_clusters.first].pack("L")
          @volume.write(buffer, current_inode_number)

          # Report back the first inode of chain. The previous call to @volume.write() will be done again by #write
          @first_inode_of_chain = new_inode_clusters.first if stopped_inode_index == -1

          # in memory, create the inode and fill it with the link and data cluster numbers
          (new_inode_clusters << 0).each_cons(2) do |new_inode_cluster, next_inode_cluster|
            current_data_clusters = new_data_clusters.slice!(0, @cluster_numbers_count_per_inode)
            buffer = ([INODE_CHAIN_FOURCC, next_inode_cluster] + current_data_clusters + Array.new(@cluster_numbers_count_per_inode - current_data_clusters.size, 0)).pack("a4LL*")
            @volume.write(buffer, new_inode_cluster)
          end
        end

        data_clusters_for(size, offset).first
      end

      def to_s
        "#<ChainedInode:#{@head_inode}>"
      end

      protected

      def offset_to_inode_index(offset)
        (offset / @volume.cluster_size) / @cluster_numbers_count_per_inode
      end

      def offset_to_inode_cluster_number_index(offset)
        (offset / @volume.cluster_size) % @cluster_numbers_count_per_inode
      end

      # Browse the inode chain. Pass a block that will receive for each inode in the chain: inode_buffer, inode_number.
      # Returns an Enumerator when called without a block.
      def inode_chain
        return to_enum(:inode_chain) unless block_given?

        current_inode_number = @first_inode_of_chain
        while current_inode_number != 0
          buffer = @volume.read(1, current_inode_number)
          raise Errno::EILSEQ.new(buffer[0..3]) if buffer[0..3] != INODE_CHAIN_FOURCC
          yield buffer, current_inode_number
          current_inode_number = buffer[4..7].unpack1("L")
        end
      end

      def extract_data_cluster_numbers(buffer)
        buffer[INODE_CHAIN_METADATA_SIZE...@volume.cluster_size].unpack("L*")
      end
    end

    register(ChainedInode::FOURCC, ChainedInode)
  end
end
