module MortimerFs
  module Allocator
    class SingleBitmapAllocator
      FOURCC = "MoAS"

      def self.for(volume)
        # Returns the same instance of the allocator when asking for the same volume instance
        @instances ||= {}
        @instances[volume] ||= new(volume)
      end

      def initialize(volume)
        @volume = volume
        @total_cluster_count = volume.total_cluster_count
        # Here until we have a real allocation scheme
        @dummy_bitmap_buffer = @volume.read(1, 1)
        @first_free_cluster = @dummy_bitmap_buffer.unpack1("L")
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

      def update_first_free_cluster
        @dummy_bitmap_buffer[0, 4] = [@first_free_cluster].pack("L")
        @volume.write(@dummy_bitmap_buffer, 1)
      end
    end

    register(SingleBitmapAllocator::FOURCC, SingleBitmapAllocator)
  end
end
