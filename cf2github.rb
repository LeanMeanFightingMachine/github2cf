#!/usr/bin/env ruby

#############################################################
# Requirements:
#				ruby + cloudfiles gem + yaml gem  + colorize gem
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

# Github credentials
GITHUB_USERNAME = "USERNAME"
GITHUB_PASSWORD = "PASSWORD"

#############################################################
# PLEASE DO NOT EDIT BELOW THIS LINE
#############################################################

require 'rubygems'
require 'fileutils'
require 'cloudfiles'
require 'yaml'
require "colorize"
  
$cfconnection = CloudFiles::Connection.new(
	 :username => CLOUDFILES_USERNAME,
	 :api_key => CLOUDFILES_API_KEY
	 #,:auth_url => CloudFiles::AUTH_UK # Add this line if you are using the UK service
)

def download_and_restore_to_github(options)
	download_from_cloudfiles(compressed_filename(options[:name]))

	puts "Uncompressing #{options[:name]} ".green
	system("cd #{CLOUDFILES_CONTAINER} && tar xzf #{compressed_filename(options[:name])} #{options[:name]}")

	create_repo_and_push(options[:clone_url])
end

def create_repo_and_push(clone_url)
	account = clone_url.split("/").first
	name = clone_url.split("/").last.split(".").first
	
	foldername = File.join(CLOUDFILES_CONTAINER, name)
	#filename = File.join(CLOUDFILES_CONTAINER, name+".git")

	ssh_url = "git@github.com:#{account}/#{name}.git"
	# PUSH IT UP!

	puts "Creating respository...".green
	uri = URI.parse("https://github.com")
	http = Net::HTTP.new(uri.host, uri.port)
	http.use_ssl = true
	http.verify_mode = OpenSSL::SSL::VERIFY_NONE

	request = Net::HTTP::Post.new("/api/v2/json/repos/create")
	request.set_form_data({'name' => "#{account}/#{name}"}, ';')
	request.basic_auth(GITHUB_USERNAME,GITHUB_PASSWORD)
	
	http.request(request) {|response|
		#puts response.inspect

		if response.code == "200"
			puts "Repository created sucessfully".yellow
			ssh_url = "git@github.com:#{account}/#{name}.git"
			# PUSH IT UP!
			
			puts "Cloning...".green
			clone_command = "git clone #{foldername} #{foldername}_clone"
			system(clone_command);
			
			puts "Pushing to github...".green
			removeremote_command = "cd #{foldername}_clone && git remote rm origin"
			setremote_command = "cd #{foldername}_clone && git remote add origin #{ssh_url}"
			system(removeremote_command);
			system(setremote_command);
			push_command = "cd #{foldername}_clone && git push -u origin master"
			puts push_command.yellow
			system(push_command);
		elsif response.code == "422"
			puts "Repository already exists. #{name} not restored.".red
		else
			puts "Couldn't create repository #{name} not restored:".red
			puts response.body.red
		end
	}
end

def compressed_filename(str)
	str+".tar.gz"
end	 

def download_from_cloudfiles(filename)
	begin
		puts "** Downloading #{filename} from Cloudfiles".green
		path = File.join(CLOUDFILES_CONTAINER, filename)
		container = $cfconnection.container(cloudfilescontainer)
		object = container.create_object(filename, false)
		object.save_to_filename(path);
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

def cloudfilescontainer
	cloudfilescontainer = CLOUDFILES_CONTAINER
end

def restore_repos_from_arguments
	ARGV.each do |arg|
		begin
			name = arg.split('/').last.split(".").first
			download_and_restore_to_github(:name => name, :clone_url => arg) 
		rescue Exception => e
			puts e.message.red
		end
	end
end


def restore_repos
	restore_repos_from_arguments
end	


begin
	# create temp dir
	Dir.mkdir(CLOUDFILES_CONTAINER) rescue nil
	restore_repos
ensure	
	# remove temp dir
	delete_dir_and_sub_dir(CLOUDFILES_CONTAINER)
end
