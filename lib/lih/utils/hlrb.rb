# Copyright (c) 2012 Wayne Walker <wwalker@solid-constructs.com>

require 'yaml'
require 'logger'

$debug=(!ENV['DEBUG'].nil? and ENV['DEBUG'] == "1") ? true : false
require 'pp' if $debug

class HardLinkRsyncBackup
  DEFAULTS={}
  DEFAULTS[:config_dir]    = '/etc/hlrb/'
  DEFAULTS[:username]      = 'root'
  DEFAULTS[:rsync_options] ='-avHxz'

  def config(key, fs_name = nil)
    if fs_name
      if @host_config
        value = @host_config[:file_systems][fs_name][key] || @host_config[key] || @system_config[key] || DEFAULTS[key]
      else
        value = @system_config[key] || DEFAULTS[key]
      end
    else
      if @host_config
        value = @host_config[key] || @system_config[key] || DEFAULTS[key]
      else
        value = @system_config[key] || DEFAULTS[key]
      end
    end
    return value
  end

  def initialize
    read_system_config
    read_host_config
    set_time_vars
    init_log
    find_latest_backup
  end

  def run
    @log.info "Beginning backup of #{config(:hostname)}"

    create_hard_link_copy
    rsync_file_systems


    @log.info "Successfully completed backup of #{config(:hostname)}"
  end

  def create_hard_link_copy
    cmd = "/bin/cp -al #{@latest_backup} #{@start_time_clean}"
    @log.debug "Hard link copy command: #{cmd}"
    @log.info "Copying  #{@latest_backup} to #{@start_time_clean} via hard links"
    `#{cmd}`
    #system('/bin/true')
    if $? != 0
      raise "Copy command <#{cmd}> failed with return code #{$?}"
    end
    @log.info "Copy complete"
  end # def create_hard_link_copy

  def rsync_file_systems
    config(:file_systems).keys.sort.each do |fs_name|
      rsync_file_system(fs_name)
    end
  end # def rsync_file_systems

  def rsync_file_system(fs_name)
    rsync = "/usr/bin/rsync"
    options = config(:rsync_options)
    command = [rsync, options, '--delete']
    if config(:excludes, fs_name)
      excludes = config(:excludes, fs_name).map{|e| ['--exclude', e]}.flatten
      command += excludes
    end
    command << (hostpath(fs_name) + sourcepath(fs_name))
    command << (@start_time_clean + sourcepath(fs_name))
    @log.debug command.pretty_inspect

    @log.info "Begin rsync of the '#{fs_name}' file_system"
    system(*command, :out => @logfilebase + ".#{fs_name}.rsync.log", :err => :out)
    #system('/bin/true')
    if $? != 0
      raise "Copy command <#{cmd}> failed with return code #{$?}"
    end
    @log.info "Completed rsync of the '#{fs_name}' file_system"
  end # def rsync_file_system

  def hostpath(fs_name)
    user = config(:username,fs_name)
    host = config(:hostname)
    return "#{user}@#{host}:"
  end # def hostpath

  def sourcepath(fs_name)
    path = config(:path, fs_name)
    if ! path.match(/\/$/)
      path += '/'
    end
    return path
  end

  def init_log
    if ! File.directory?(config(:backup_dir) + ARGV[0] + '/logs/')
      Dir.mkdir(config(:backup_dir) + ARGV[0] + '/logs/')
    end
    @logfilebase = config(:backup_dir) + ARGV[0] + '/logs/' + @start_time_clean
    @logfile = File.open(@logfilebase + '.log', 'a')
    @log = Logger.new(@logfile)
    @log.level=Logger::DEBUG
    @log.info "Starting hlrb for host #{ARGV[0]} at #{@start_time_clean}"
  end # def init_log

  def set_time_vars
    @start_time = Time.now
    # format for filename inclusion and strip seconds
    @start_time_clean = @start_time.strftime('%Y-%m-%d_%H-%M-00')
  end # def set_time_vars

  def read_system_config
    @system_config = []

    system_confg_yaml = File.read(DEFAULTS[:config_dir] + 'system.yaml')
    @system_config = YAML::load(system_confg_yaml)
  end # def read_system_config

  def read_host_config
    hostname = ARGV[0]

    host_confg_yaml = File.read(config(:config_dir) + hostname + '.yaml')
    @host_config = YAML::load(host_confg_yaml)
  end # def read_host_config

  def find_latest_backup
    @original_pwd = Dir.pwd
    Dir.chdir(config(:backup_dir) + config(:hostname))
    @latest_backup = Dir.glob('20*').grep(/^20\d\d-\d\d-\d\d_\d\d-\d\d-\d\d$/).sort[-1]
    if ! @latest_backup
      raise "No existing base backup.  Possibly mkdir #{config(:backup_dir) + config(:hostname) + '/' + @start_time_clean}"
    else
      @log.info "Found previous backup to be #{@latest_backup}"
    end
  end # def find_latest_backup
end
