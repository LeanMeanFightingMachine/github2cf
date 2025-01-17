#!/usr/bin/env ruby

#############################################################
# Requirements:
#				ruby + cloudfiles gem + yaml gem + colorize gem
#				git
#
# By: Steve Mckellar (http://www.leanmeanfightingmachine.co.uk)
# Based on github2s3 by: Akhil Bansal (http://webonrails.com)
#############################################################


#############################################################
# CONFIGURATION SETTINGS: Please change your Rackspace cloud credentials

# Cloudfiles credentials
CLOUDFILES_USERNAME = "USERNAME"
CLOUDFILES_API_KEY = "API_KEY"

# Cloudfiles container name to put dumps
CLOUDFILES_CONTAINER = "github_backup"

#############################################################
# PLEASE DO NOT EDIT BELOW THIS LINE
#############################################################

require 'rubygems'
require 'fileutils'
require 'cloudfiles'
require 'yaml'
require "colorize"

REPOSITORY_FILE = File.dirname(__FILE__) + '/github_repos.yml'
  
$cfconnection = CloudFiles::Connection.new(
	:username => CLOUDFILES_USERNAME,
	:api_key => CLOUDFILES_API_KEY
	#,:auth_url => CloudFiles::AUTH_UK # Add this line if you are using the UK service
)

def  clone_and_upload_to_cloudfiles(options)
	#clean_name = options[:name].split(".").first
	puts "\n\nChecking out #{options[:name]} ...".green
	clone_command = "cd #{CLOUDFILES_CONTAINER} && git clone --bare git@github.com:#{options[:clone_url]} #{options[:name]}"
	puts clone_command.yellow
	system(clone_command)
	
	if File.exists?("#{CLOUDFILES_CONTAINER}/#{options[:name]}")
		puts "Compressing #{options[:name]} ".green
		system("cd #{CLOUDFILES_CONTAINER} && tar czf #{compressed_filename(options[:name])} #{options[:name]}")

		upload_to_cloudfiles(compressed_filename(options[:name]))
		
		puts "-------------------------------------------------------------------------------------".light_red
		puts "To delete the github hosted repository, please go to:".light_red
		puts "https://github.com/#{account}/#{shortname}/admin".underline.light_red
		puts "-------------------------------------------------------------------------------------".light_red
	else
		puts "!!! CLONE FAILED: Repository (probably) does not exist".red
	end
end

def compressed_filename(str)
	str+".tar.gz"
end	 
 
def upload_to_cloudfiles(filename)
	begin
		puts "** Uploading #{filename} to Cloudfiles".green
		path = File.join(CLOUDFILES_CONTAINER, filename)
		container = $cfconnection.container(cloudfilescontainer)
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
		puts "Checking container exists..."
		raise "No such container" if !$cfconnection.container_exists?(cloudfilescontainer)
	rescue
		puts "Container '#{cloudfilescontainer}' not found."
		puts "Creating Container '#{cloudfilescontainer}'. "

		begin 
			$cfconnection.create_container(cloudfilescontainer)
			# make sure it's private!
			puts "Created Container '#{cloudfilescontainer}'. "
		rescue Exception => e
			puts e.message
		end
	end
end

def ensure_container_private
	begin
		puts "Checking container is private..."
		container = $cfconnection.container(cloudfilescontainer)
		raise "Container isn't private" if container.public?
	rescue
		puts "Container '#{cloudfilescontainer}' isn't private."
		puts "Setting container '#{cloudfilescontainer}' as private. "

		begin 
			container.make_private
			# make sure it's private!
			puts "Set container '#{cloudfilescontainer}' as private. "
		rescue Exception => e
			puts e.message
		end
	end
end

def cloudfilescontainer
	cloudfilescontainer = CLOUDFILES_CONTAINER
end


def backup_repos_from_yaml 
	if File.exist?(REPOSITORY_FILE)
		repos = YAML.load_file(REPOSITORY_FILE)
		repos.each{ |repo|
			clone_and_upload_to_cloudfiles(:name => repo[0], :clone_url => repo[1]['git_clone_url'])
		}
	else
		puts "Repository YAML file(./github_repos.yml) file not found".red
	end
end

def back_repos_from_arguments
	ARGV.each do |arg|
		begin
			name = arg.split('/').last.split(".").first
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
		backup_repos_from_yaml
	end
end	


begin
	# create temp dir
	Dir.mkdir(CLOUDFILES_CONTAINER) rescue nil
	ensure_container_exists
	ensure_container_private
	backup_repos
ensure	
	# remove temp dir
	delete_dir_and_sub_dir(CLOUDFILES_CONTAINER)
end
