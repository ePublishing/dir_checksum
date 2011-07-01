# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "dir_checksum"

Gem::Specification.new do |s|
  s.name        = "dir_checksum"
  s.version     = DirChecksum::VERSION
  s.authors     = ["David McCullars"]
  s.email       = ["dmccullars@ePublishing.com"]
  s.homepage    = ""
  s.summary     = %q{Ruby library to recursively checksum a directory}
  s.description = %q{Ruby library to recursively checksum a directory (and later diff working directory against the checksum)}

  s.rubyforge_project = "dir_checksum"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
