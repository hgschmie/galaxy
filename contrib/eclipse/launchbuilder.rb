#! /usr/bin/env ruby

#
# Takes a local galaxy installation, load the necessary pieces to figure out the slot configuration
# and modify an eclipse launcher file to run a local service as if it were started inside the slot.
#
#
# Parameters:
#
# <galaxy install folder> - the folder that galaxy was installed locally.
# <slot number>           - the slot number (*not* the agent id). A slot usually is s0, s1, s2 etc.
# <eclipse launch file>   - an eclipse launch file for a project. This launch file will be modified
#                           and the result returned on stdout.
#
# Caveat:
#
# launchbuilder assumes the configuration layout as written by galaxy-prep. It will not work if
# the local galaxy installation is radically different from what prep generates.
#

require 'rubygems'
require 'xmlsimple'
require 'galaxy/scripts'

ARGV.length == 3 || raise("Usage: #{$0} <galaxy install folder> <slot name> <eclipse launch file>")

VM_ARGS='org.eclipse.jdt.launching.VM_ARGUMENTS'
WORK_DIR='org.eclipse.jdt.launching.WORKING_DIRECTORY'

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

@launchfile = XmlSimple.xml_in(ARGV[2], { 'ForceArray' => true })

@vmargs = nil
@workdir = nil

@launchfile['stringAttribute'].each { |entry| 
  @vmargs = entry if (entry['key'] == VM_ARGS)
  @workdir = entry if (entry['key'] == WORK_DIR)
}

if @vmargs.nil? 
  @vmargs = { 
    'key' => VM_ARGS,
    'value' => nil
  }

  @launchfile['stringAttribute'] << @vmargs
end

if @workdir.nil? 
  @workdir = { 
    'key' => WORK_DIR,
    'value' => nil
  }

  @launchfile['stringAttribute'] << @workdir
end

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

config=config_opts.join("&#10;")
jvm_opts=@scripts.get_jvm_opts.join("&#10;")
galaxy=@scripts.get_java_galaxy_env.join("&#10;")

@vmargs['value'] = "#{jvm_opts}&#10;#{config}&#10;#{galaxy}"
@workdir['value'] = @scripts.base

result=XmlSimple.xml_out(@launchfile, {'RootName' => 'launchConfiguration'})

#
# xmlsimple writes &amp;#10;, replace the &amp; with the ampersand again.
# Is there a way to write &#<num>; syntax with xmlsimple?
#
puts result.gsub(/&amp;/, '&')
