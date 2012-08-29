#! /usr/bin/env ruby

#
# Takes a local galaxy installation, load the necessary pieces to figure out the slot configuration
# and returns the list of defines required to run a local service e.g. in an IDE just as if it were
# deployed to that slot.
#
#
# Parameters:
#
# <galaxy install folder> - the folder that galaxy was installed locally.
# <slot number>           - the slot number (*not* the agent id). A slot usually is s0, s1, s2 etc.
#
#

require 'rubygems'
require 'xmlsimple'
require 'galaxy/scripts'

ARGV.length == 2 || raise("Usage: #{$0} <galaxy install folder> <slot name>")

#
# find the data folder in the agent config
#

config_file = "#{ARGV[0]}/config/agent-#{ARGV[1]}.conf"
begin 
  config = YAML.load_file(config_file)
  data_folder = config['galaxy.agent.data-dir']
  args = [ "--slot-info", data_folder + "/slot_info" ]
  @scripts = Galaxy::ScriptSupport.new args
rescue Exception => e
  raise ("Could not load configuration from galaxy (#{config_file}), is the slot #{ARGV[1]} set up?")
end

@scripts.base = config['galaxy.agent.deploy-dir'] + "/current"

#
# The next piece was taken from the launcher.standalone in the components-ness-galaxy.
#

config_opts = [
               "-Dness.config.location=file:#{@scripts.config_location}",
               "-Dness.config=#{@scripts.config_path}"
              ]

if File.exists?("#{@scripts.base}/log4j.xml")
  config_opts << "-Dlog4j.configuration=file:#{@scripts.base}/log4j.xml"
end

if @scripts.respond_to?("tmp_dir") && ! @scripts.tmp_dir.nil?
  config_opts << "-Djava.io.tmpdir=#{@scripts.tmp_dir}"
end

config=config_opts.join(" ")
jvm_opts=@scripts.get_jvm_opts.join(" ")
galaxy=@scripts.get_java_galaxy_env.join(" ")

puts "Options:#{jvm_opts} #{config} #{galaxy}"
puts "Basedir: #{@scripts.base}"

