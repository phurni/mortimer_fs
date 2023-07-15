module MortimerFs
  module Directory
    class FixedEntryDirectory < File
      include Enumerable

      FOURCC = "MoD0"

      DIR_ENTRY_SIZE = 256
      DIR_ENTRY_MAX_NAMESIZE = DIR_ENTRY_SIZE - 16
      DIR_ENTRY_PACK_FORMAT = "a4LLLZ#{DIR_ENTRY_MAX_NAMESIZE}"
      
      FLAG_DELETED = 1

      def find_inode_number_for(name)
        _, inode_number = find {|item_name, _| item_name == name }
        inode_number or raise Errno::ENOENT.new
      end

      def each(&block)
        offset = 0
        until (buffer = read(DIR_ENTRY_SIZE, offset)).empty?
          entry_fields = parse_dir_entry(buffer)
          offset += DIR_ENTRY_SIZE
          next if (entry_fields[2] & FLAG_DELETED) != 0

          yield [entry_fields.last, entry_fields[1]]
        end
        self
      end

      def add(name, inode_number)
        raise Errno::ENAMETOOLONG if name.bytesize >= DIR_ENTRY_MAX_NAMESIZE
        entry_fields = [FOURCC, inode_number, 0, 0, name]

        write(entry_fields.pack(DIR_ENTRY_PACK_FORMAT), size)
      end

      def remove(name)
        offset = 0
        until (buffer = read(DIR_ENTRY_SIZE, offset)).empty?
          entry_fields = parse_dir_entry(buffer)
          if entry_fields.last == name
            # We found the entry, mark it as deleted
            entry_fields[2] = FLAG_DELETED
            # Write it back and bail
            write(entry_fields.pack(DIR_ENTRY_PACK_FORMAT), offset)
            return
          end
          offset += DIR_ENTRY_SIZE
        end
        raise Errno::ENOENT.new
      end

      protected

      def parse_dir_entry(buffer)
        raise Errno::EDOM.new unless buffer.size == DIR_ENTRY_SIZE
        raise Errno::EILSEQ.new(buffer[0..3]) unless buffer[0..3] == FOURCC

        buffer.unpack(DIR_ENTRY_PACK_FORMAT)
      end
    end

    register(FixedEntryDirectory::FOURCC, FixedEntryDirectory)
  end
end
