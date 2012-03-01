require 'rubygems'
require 'fileutils'
require 'tmpdir'
require 'rake'
require 'rake/testtask'
require 'rake/clean'
require 'rubygems/package_task'
require 'lib/galaxy/version'
begin
    require 'rcov/rcovtask'
    $RCOV_LOADED = true
rescue LoadError
    $RCOV_LOADED = false
    puts "Unable to load rcov"
end

THIS_FILE = File.expand_path(__FILE__)
PWD = File.dirname(THIS_FILE)
RUBY = File.join(Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name'])

PACKAGE_NAME = 'galaxy'
PACKAGE_VERSION = Galaxy::Version
GEM_VERSION = PACKAGE_VERSION.split('-')[0]

task :default => [:test]

task :install do
  sitelibdir = Config::CONFIG["sitelibdir"]
  cd 'lib' do
    for file in Dir["galaxy/*.rb", "galaxy/commands/*.rb" ]
      d = File.join(sitelibdir, file)
      mkdir_p File.dirname(d)
      install(file, d)
    end
  end

  bindir = Config::CONFIG["bindir"]
  cd 'bin' do
    for file in ["galaxy", "galaxy-agent", "galaxy-console" ]
      d = File.join(bindir, file)
      mkdir_p File.dirname(d)
      install(file, d)
    end
  end
end


Rake::TestTask.new("test") do |t|
  t.pattern = 'test/test*.rb'
  t.libs << 'test'
  t.warning = true
end

if $RCOV_LOADED
    Rcov::RcovTask.new do |t|
      t.pattern = 'test/test*.rb'
      t.libs << 'test'
      t.rcov_opts = ['--exclude', 'gems/*', '--text-report']
    end
end

Rake::PackageTask.new(PACKAGE_NAME, PACKAGE_VERSION) do |p|
  p.tar_command = 'gtar' if RUBY_PLATFORM =~ /solaris/
  p.need_tar = true
  p.package_files.include(["lib/galaxy/**/*.rb", "bin/*"])
end

spec = Gem::Specification.new do |s|
  s.name = PACKAGE_NAME
  s.version = GEM_VERSION
  s.author = "Trumpet Technologies"
  s.email = "henning@trumpet.io"
  s.homepage = "http://github.com/henning/galaxy"
  s.platform = Gem::Platform::RUBY
  s.summary = "Galaxy is a lightweight software deployment and management tool."
  s.files =  FileList["lib/galaxy/**/*.rb", "bin/*"]
  s.executables = FileList["galaxy-agent", "galaxy-console", "galaxy"]
  s.require_path = "lib"
  s.add_dependency("json", ">= 1.5.1")
  s.add_dependency("mongrel", ">= 1.1.5")
  s.add_dependency("rcov", ">= 0.9.9")
end

Gem::PackageTask.new(spec) do |pkg|
  pkg.need_zip = false
  pkg.need_tar = false
end

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

desc "Build a Gem with the full version number"
task :versioned_gem => :gem do
  gem_version = PACKAGE_VERSION.split('-')[0]
  if gem_version != PACKAGE_VERSION
    FileUtils.mv("pkg/#{PACKAGE_NAME}-#{gem_version}.gem", "pkg/#{PACKAGE_NAME}-#{PACKAGE_VERSION}.gem")
  end
end

namespace :package do
  desc "Build an RPM package"
  task :rpm => :versioned_gem do
    build_dir = "/tmp/galaxy-package"
    rpm_dir = "/tmp/galaxy-rpm"
    rpm_version = PACKAGE_VERSION
    rpm_version += "-final" unless rpm_version.include?('-')

    FileUtils.rm_rf(build_dir)
    FileUtils.mkdir_p(build_dir)
    FileUtils.rm_rf(rpm_dir)
    FileUtils.mkdir_p(rpm_dir)

    `rpmbuild --target=noarch -v --define "_builddir ." --define "_rpmdir #{rpm_dir}" -bb build/rpm/galaxy.spec` || raise("Failed to create package")
    # You can tweak the rpm as follow:
    #`rpmbuild --target=noarch -v --define "_gonsole_url gonsole.company.com" --define "_gepo_url http://gepo.company.com/config/trunk/prod" --define "_builddir ." --define "_rpmdir #{rpm_dir}" -bb build/rpm/galaxy.spec` || raise("Failed to create package")

    FileUtils.cp("#{rpm_dir}/noarch/#{PACKAGE_NAME}-#{rpm_version}.noarch.rpm", "pkg/#{PACKAGE_NAME}-#{rpm_version}.noarch.rpm")
    FileUtils.rm_rf(build_dir)
    FileUtils.rm_rf(rpm_dir)
  end

end
