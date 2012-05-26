# encoding: utf-8
$:.unshift File.join(File.dirname(__FILE__), 'lib', 'galaxy')
require 'version'

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
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
  desc "Run a Gonsole locally"
  task :gonsole do
    # Note that -i localhost is needed. Otherwise the DRb server will bind to the
    # hostname, which can be as ugly as "Pierre-Alexandre-Meyers-MacBook-Pro.local"
    system(RUBY, "-I", File.join(PWD, "lib"),
           File.join(PWD, "bin", "galaxy-console"), "--start",
           "-i", "localhost",
           "--ping-interval", "10", "-f", "-l", "STDOUT", "-L", "DEBUG", "-v")
  end

  desc "Run a Gagent locally"
  task :gagent do
    system(RUBY, "-I", File.join(PWD, "lib"),
           File.join(PWD, "bin", "galaxy-agent"), "--start",
           "-i", "local_test", "-g", "local_group", 
           "-U", "druby://localhost:4441", "-c", "localhost",
           "-r", "http://localhost/config/trunk/qa",
           "-b", "http://localhost/binaries",
           "-d", "/tmp/deploy", "-x", "/tmp/extract",
           "--announce-interval", "10", "-f", "-l", "STDOUT", "-L", "DEBUG", "-v")
  end
end

namespace :package do
  desc "Build an RPM package"
  task :rpm => :gemspec do
    `gem build galaxy.gemspec`
    `gem install galaxy-#{PACKAGE_VERSION}`
    build_dir = "/tmp/galaxy-package"
    rpm_dir = "/tmp/galaxy-rpm"
    rpm_version = PACKAGE_VERSION
    rpm_version += "-final" unless rpm_version.include?('-')

    FileUtils.rm_rf(build_dir)
    FileUtils.mkdir_p(build_dir)
    FileUtils.rm_rf(rpm_dir)
    FileUtils.mkdir_p(rpm_dir)

    `rpmbuild --target=noarch -v --define "_builddir ." --define "_rpmdir #{rpm_dir}" -bb distro/redhat/rpm/galaxy.spec` || raise("Failed to create package")
    # You can tweak the rpm as follow:
    #`rpmbuild --target=noarch -v --define "_gonsole_url gonsole.company.com" --define "_gepo_url http://gepo.company.com/config/trunk/prod" --define "_builddir ." --define "_rpmdir #{rpm_dir}" -bb build/rpm/galaxy.spec` || raise("Failed to create package")

    FileUtils.cp("#{rpm_dir}/noarch/#{PACKAGE_NAME}-#{rpm_version}.noarch.rpm", "#{PACKAGE_NAME}-#{rpm_version}.noarch.rpm")
    FileUtils.rm_rf(build_dir)
    FileUtils.rm_rf(rpm_dir)
  end

end
