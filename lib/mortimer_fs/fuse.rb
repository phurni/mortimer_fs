require 'rfuse'

module MortimerFs
  class Fuse
    FTYPE_MORTIMER_TO_RFUSE = {
      file: RFuse::Stat::S_IFREG,
      directory: RFuse::Stat::S_IFDIR,
      symlink: RFuse::Stat::S_IFLNK,
    }

    def self.main(argv)
      RFuse.main(argv) do |options, argv|
        device_path = options[:device] || raise(RFuse::Error.new("Please pass a device path as first argument"))
        device = ::File.open(device_path, "r+b") rescue raise(RFuse::Error.new("can't open device \"#{device_path}”\": #{$!.message}"))
        device.sync = true
        new(device)
      end
    end

    attr_reader :volume

    def initialize(device)
      @volume = Volume.new(device)
    end

    def getattr(ctx, path)
      inode = @volume.inode_fetch(path_to_inode_number(path))
      RFuse::Stat.new(FTYPE_MORTIMER_TO_RFUSE[inode.type], inode.mode, inode.stat_hash)
    end

    def readdir(ctx, path, filler, offset, ffi)
      @volume.directory_open(path_to_inode_number(path)) do |dir|
        dir.each do |name, inode_number|
          inode = @volume.inode_fetch(inode_number)
          filler.push(name, RFuse::Stat.new(inode.mode, inode.mode, inode.stat_hash), 0)
        end
      end
    end

    def mkdir(ctx, path, mode)
      @volume.directory_open(path_to_inode_number(::File.dirname(path)), flags: File::WRONLY) do |dir|
        now_timestamp = Time.now.to_i
        inode_number = @volume.inode_make({type: :directory, mode: mode, size: 0, uid: ctx.uid, gid: ctx.gid, ctime: now_timestamp, mtime: now_timestamp, atime: now_timestamp})

        dir.add(::File.basename(path), inode_number)
      end
    end

    def mknod(ctx, path, mode, major, minor)
      @volume.directory_open(path_to_inode_number(::File.dirname(path)), flags: File::WRONLY) do |dir|
        now_timestamp = Time.now.to_i
        inode_number = @volume.inode_make({type: :file, mode: mode, size: 0, uid: ctx.uid, gid: ctx.gid, ctime: now_timestamp, mtime: now_timestamp, atime: now_timestamp})

        dir.add(::File.basename(path), inode_number)
      end
    end

    def rmdir(ctx, path)
      @volume.directory_open(path_to_inode_number(::File.dirname(path)), flags: File::RDWR) do |dir|
        dir.remove(::File.basename(path))
      end
    end

    def unlink(ctx, path)
      @volume.directory_open(path_to_inode_number(::File.dirname(path)), flags: File::RDWR) do |dir|
        dir.remove(::File.basename(path))
      end
    end

    #def link(ctx, from, to)
    #end

    #def rename(ctx, from, to)
    #end

    #def symlink(ctx, to, from)
    #end

    #def readlink(ctx, path, size)
    #end

    def chmod(ctx, path, mode)
      inode = @volume.inode_fetch(path_to_inode_number(path))
      inode.mode = mode
      inode.write
    end

    def chown(ctx, path, uid, gid)
      inode = @volume.inode_fetch(path_to_inode_number(path))
      inode.uid = uid
      inode.gid = gid
      inode.write
    end

    def utime(ctx, path, atime, mtime)
      inode = @volume.inode_fetch(path_to_inode_number(path))
      inode.atime = atime
      inode.mtime = mtime
      inode.write
    end

    def truncate(ctx, path, offset)
      inode = @volume.inode_fetch(path_to_inode_number(path))
      inode.size = offset
      inode.write
    end

    #def create(ctx, path, mode, ffi)
    #end

    def open(ctx, path, ffi)
      inode = @volume.inode_fetch(path_to_inode_number(path))
      raise Errno::EISDIR if inode.type == :directory

      ffi.fh = File.new(@volume, inode, flags: ffi.flags)
    end

    def read(ctx, path, size, offset, ffi)
      raise Errno::EINVAL unless ffi.fh.is_a? File
      ffi.fh.read(size, offset)
    end

    def write(ctx, path, data, offset, ffi)
      raise Errno::EINVAL unless ffi.fh.is_a? File
      ffi.fh.write(data, offset)
    end

    def release(ctx, path, ffi)
      ffi.fh.close if ffi.fh.is_a? File
    end

    #def ftruncate(ctx, path, offset, ffi)
    #end

    #def fsync(ctx, path, datasync, ffi)
    #end

    #def fgetattr(ctx, path, ffi)
    #end

    #def flush(ctx, path, ffi)
    #end

    protected

    def path_to_inode_number(path)
      inode_number = @volume.root_inode_number
      path.split('/').each do |segment|
        next if segment == ''
        inode_number = @volume.directory_open(inode_number) {|dir| dir.find_inode_number_for(segment) }
      end
      inode_number
    ensure
      puts ">>> path_to_inode_number(#{path}) => #{inode_number}"
    end

  end
end
