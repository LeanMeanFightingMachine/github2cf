#!/usr/bin/env ruby

#############################################################
# Requirements:
#				ruby + cloudfiles gem + colorize gem
#				git
#
# Rackspace version by: Steve Mckellar (http://www.leanmeanfightingmachine.co.uk)
# Based on github2s3 by: Akhil Bansal (http://webonrails.com)
#############################################################


#############################################################
# CONFIGURATION SETTINGS: Please change your Rackspace cloud credentials

# Cloudfiles credentials

CLOUDFILES_USERNAME = "TEST"
CLOUDFILES_API_KEY = "TEST"

# Cloudfiles container name to put dumps
CLOUDFILES_CONTAINER = "TEST"


#############################################################
# PLEASE DO NOT EDIT BELOW THIS LINE
#############################################################

require 'rubygems'
require 'fileutils'
require 'cloudfiles'
require 'yaml'
require "colorize"

REPOSITORY_FILE = File.dirname(__FILE__) + '/github_repos.yml'
  
cfconnection = CloudFiles::Connection.new(
  :username => CLOUDFILES_USERNAME,
  :api_key => CLOUDFILES_API_KEY,
  :auth_url => CloudFiles::AUTH_UK # Remove this if you are outside of the UK
)

def  clone_and_upload_to_cloudfiles(options)
	 puts "\n\nChecking out #{options[:name]} ...".green
	 clone_command = "cd #{CLOUDFILES_CONTAINER} && git clone --bare #{options[:clone_url]} #{options[:name]}"
   puts clone_command.yellow
   system(clone_command)
	 puts "\n Compressing #{options[:name]} ".green
	 system("cd #{CLOUDFILES_CONTAINER} && tar czf #{compressed_filename(options[:name])} #{options[:name]}")
	 
	 upload_to_cloudfiles(compressed_filename(options[:name]))
	 
 end
 
 def compressed_filename(str)
	 str+".tar.gz"
 end	 
 
 def upload_to_cloudfiles(filename)
	 begin
		puts "** Uploading #{filename} to Cloudfiles".green
		path = File.join(CLOUDFILES_CONTAINER, filename)
		#S3Object.store(filename, File.read(path), cloudfilescontainer)
		container = cfconnection.container(cloudfilescontainer)
		object = container.create_object(filename, false)
    object.write(File.read(path));
    
	 rescue Exception => e
		puts "Could not upload #{filename} to Cloudfiles".red
		puts e.message.red
	 end
 end
  
def delete_dir_and_sub_dir(dir)
  Dir.foreach(dir) do |e|
    # Don't bother with . and ..
    next if [".",".."].include? e
    fullname = dir + File::Separator + e
    if FileTest::directory?(fullname)
      delete_dir_and_sub_dir(fullname)
    else
      File.delete(fullname)
    end
  end
  Dir.delete(dir)
end

def ensure_container_exists
  begin
    raise "No such container" if !cfconnection.container_exists?(cloudfilescontainer);
  rescue
    puts "Container '#{cloudfilescontainer}' not found."
    puts "Creating Container '#{cloudfilescontainer}'. "

    begin 
      cfconnection.create_container(cloudfilescontainer)
      # make sure it's private!
      puts "Created Container '#{cloudfilescontainer}'. "
    rescue Exception => e
      puts e.message
    end
  end
end

def cloudfilescontainer
	cloudfilescontainer = CLOUDFILES_CONTAINER
end


def backup_repos_form_yaml 
    if File.exist?(REPOSITORY_FILE)
      repos = YAML.load_file(REPOSITORY_FILE)
      repos.each{|repo| clone_and_upload_to_cloudfiles(:name => repo[0], :clone_url => repo[1]['git_clone_url']) }
    else
	    puts "Repository YAML file(./github_repos.yml) file not found".red
    end
end

def back_repos_from_arguments
	ARGV.each do |arg|
		begin
			name = arg.split('/').last
			clone_and_upload_to_cloudfiles(:name => name, :clone_url => arg) 
		rescue Exception => e
			puts e.message.red
		end
	end
end


def backup_repos
	if ARGV.size > 0
		back_repos_from_arguments
	else
		backup_repos_form_yaml
	end
end	


begin
	# create temp dir
	Dir.mkdir(CLOUDFILES_CONTAINER) rescue nil
	ensure_container_exists
	backup_repos
ensure	
	# remove temp dir
	delete_dir_and_sub_dir(CLOUDFILES_CONTAINER)
end

