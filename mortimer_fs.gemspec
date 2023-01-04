Gem::Specification.new do |s|
  s.name        = 'mortimer_fs'
  s.version     = '0.0.1'
  s.licenses    = ['MIT']
  s.summary     = "Experiments in file system implementation using FUSE"
  s.description = "Block device backed FileSystem implementation for learning purpose"
  s.authors     = ["Pascal Hurni"]
  s.email       = 'gem@pragmaticpurist.org'
  s.homepage    = 'https://github.com/phurni/mortimer_fs'
  s.metadata    = { "source_code_uri" => "https://github.com/phurni/mortimer_fs" }

  s.required_ruby_version = '>= 2.5.0'
  s.add_runtime_dependency 'rfuse', '>= 1.1'

  s.executables << "fuse_mortimer_fs"
  s.executables << "mkmortimerfs"

  s.files = ["README.md", "mortimer_fs.gemspec"]
  s.files += Dir['lib/**/*.rb'] + Dir['bin/*']
  s.files += Dir['doc/**/*']
end
