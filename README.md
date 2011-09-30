Github2cf
=========

Description
-----------

These ruby scripts allow you to make an archive of github repository to Rackspace Cloudfiles, and restore it at a later date.

Instructions
------------

###Archive

1. Make sure that you've put your details into the configuration at the top of the script.
2. $ ./github2cf.rb [Organisation/Username]/[Repo name].git
3. Sit back and relax!

###Restore

1. Make sure that you've put your details into the configuration at the top of the script.
2. $ ./cf2github.rb [Organisation/Username]/[Repo name].git
3. Sit back and relax! 

Requirements
------------
- ruby
- cloudfiles gem
- yaml gem
- colorize gem

Missing features/roadmap
------------------------
- Lacks any checks for whether file already exists in archive, overwrites -should move previous file to a dated file.
