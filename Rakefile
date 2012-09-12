# encoding: utf-8
$:.unshift File.join(File.dirname(__FILE__), 'lib', 'galaxy')
require 'version'

require 'rubygems'
require 'rake'

PACKAGE_NAME = 'galaxy'
PACKAGE_VERSION = Galaxy::Version
GEM_VERSION = PACKAGE_VERSION.split('-')[0]

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = PACKAGE_NAME
  gem.version = GEM_VERSION
  gem.homepage = "http://github.com/NessComputing/galaxy"
  gem.summary = %Q{Galaxy is a lightweight software deployment and management tool.}
  gem.description = %Q{Galaxy}
  gem.email = "eng@likeness.com"
  gem.authors = ["Ness Computing"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

if RUBY_VERSION =~ /^1\.9/
  desc "Code coverage detail"
  task :simplecov do
    ENV['COVERAGE'] = "true"
    Rake::Task['test'].execute
  end
else
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/test*.rb'
    test.verbose = true
    test.rcov_opts << '--exclude "gems/*"'
  end
end

task :default => :test

require 'fileutils'
require 'tmpdir'
require 'rake/clean'

PWD = File.expand_path(File.dirname(__FILE__))
RUBY = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name'])

namespace :run do
  desc "Run a Galaxy Console locally"
  task :gonsole do
    # Note that -i localhost is needed. Otherwise the DRb server will bind to the
    # hostname, which can be as ugly as "Pierre-Alexandre-Meyers-MacBook-Pro.local"
    system(RUBY, "-I", File.join(PWD, "lib"),
           File.join(PWD, "bin", "galaxy-console"), "--start",
           "--announcement-url", "http://localhost:4442",
           "-i", "localhost",
           "--ping-interval", "10", "-f", "-l", "STDOUT", "-L", "DEBUG", "-v")
  end

  desc "Run a Galaxy Agent locally"
  task :gagent do
    system(RUBY, "-I", File.join(PWD, "lib"),
           File.join(PWD, "bin", "galaxy-agent"), "--start",
           "-i", "local_test", "-g", "local_group", 
           "-U", "druby://localhost:4441", "-c", "localhost",
           "-r", "http://localhost/config/trunk/qa",
           "-b", "http://localhost/binaries",
           "-d", "/tmp/deploy", "-x", "/tmp/extract",
           "--console", "http://localhost:4442",
           "--announce-interval", "10", "-f", "-l", "STDOUT", "-L", "DEBUG", "-v")
  end
end

end
