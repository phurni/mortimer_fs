require 'mortimer_fs/volume'
require 'mortimer_fs/file'
require 'mortimer_fs/directory'
require 'mortimer_fs/inode'

Dir[File.join(__dir__, "mortimer_fs/directory/*.rb")].each {|file| require_relative file }
Dir[File.join(__dir__, "mortimer_fs/inode/*.rb")].each {|file| require_relative file }

module MortimerFs
  VERSION = "0.0.1"
end
