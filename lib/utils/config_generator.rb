# Utils::ConfigGenerator -- generate configs based on yaml, erb
# templates, or default conf files
#
# License: http://codecafe.com/LICENSE-mit
#
# Copyright (c) 2012 Taylor Carpenter <taylor@codecafe.com>

$debug=(!ENV['DEBUG'].nil? and ENV['DEBUG'] == "1") ? true : false
require 'pp' if $debug

require 'fileutils'
require 'yaml'
require 'erb'

module LIH
  module Utils
    class ConfigGenerator
      attr_accessor :config, :conf_dir, :files_path, :templates_path, :tmpl_ext, :force
      @@default_template_ext = 'erb'
      @@default_conf_dir  = '/etc'

      def initialize(args={})
        @tmpl_ext = @@default_template_ext
        @create_directories = args[:create_directories].nil? ? false : true

        if $debug
          print "ConfigGenerator initialize args: "
          pp args
          puts
        end

        @force = args[:force] || false

        @conf_dir = args[:conf_dir] || @@default_conf_dir
        @files_path = args[:files_path]
        @templates_path = args[:templates_path]

        config_file = args[:config_file]

        unless File.exists?(config_file)
          puts "No configuration found!"
          exit 1
        end
        
        @config = YAML.load_file(config_file)
      end

      # Simple helper to show relative path
      def rpath(path)
        path.sub(ENV['PWD'], ".")
      end

      def generate_config_files(conf_list=[])
        return if conf_list.empty?

        puts "#generate_config_files()" if $debug

        FileUtils.mkdir_p(@conf_dir) if @create_directories and not File.exists?(@conf_dir)

        puts "conf list: #{conf_list.inspect}" if $debug

        conf_list.each do |conf|
          conf_path = "#{@conf_dir}/#{conf}"
          tmpl_path = "#{@templates_path}/#{conf}.#{@tmpl_ext}"
          file_path = "#{@files_path}/#{conf}"
        
          if File.exists?(tmpl_path) and
            (@force or !File.exists?(conf_path) or
             (File.mtime(tmpl_path) > File.mtime(conf_path)))

            tmpl = File.open(tmpl_path, 'r').read
            c = @config[conf.sub(/\.(conf|txt)$/,"").to_sym] # NOTE: Does not deal with conflicting conf names
        
            puts "Creating #{rpath(conf_path)} from #{rpath(tmpl_path)}"
            File.open("#{conf_path}", "w") do |o|
              begin
                o.puts ERB.new(tmpl, nil, "").result(binding)
              rescue NoMethodError => ex
                $stderr.puts
                $stderr.puts ex.backtrace if $debug
                $stderr.puts  "ERROR: #{ex.message} (#{ex.class})"
                $stderr.puts
                FileUtils.rm(conf_path) if File.exists?(conf_path)
                exit 1
              end
            end
          elsif File.exists?(file_path)
            next unless (@force or !File.exists?(conf_path) or File.mtime(file_path) > File.mtime(conf_path))
            puts "Copying #{rpath(files_path)}/#{conf} to #{rpath(conf_path)}"
            FileUtils.cp("#{files_path}/#{conf}", conf_path)
          end
          # TODO: maybe throw error if nothing is found for config file in list
        end
      end
    end
  end
end
