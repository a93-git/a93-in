# a93.in

Personal site - a place to call home on the Internet.

## Workflow
There is a webserver capable of receiving files via SCP protocol and the 
remote keys are already configured.

On local machine there is a config file containing a list of files that need 
to be moved to the webserver and the location on the machine

Edits are made to the files on local system and once the edits are complete, 
generate the html files using the available scripts and then run the deploy 
script to transfer the files to the webserver.

Once the deployment script has run, refreshing the web page will show the 
updated content.

## `.scpconfig` file
This file contains the files/directories that need to be scp'd to the remote 
server. Each line is a separate entity to be transferred (either a file or a 
directory). Directories don't end with a forward slash `/`. Each entity is a 
space separated list of local path and remote path. A sample file looks like
this:
```
html /var/www/my_site
index.html /var/www/my_site
css /var/www/my_site
```
All file transfers are recursive in nature. There is no option to exclude the 
files or folders as of now. Also, there is no provision to add comments to the 
config file

## TODO
- [x] Ruby script to generate links and headers from the files in a directory
- [x] Generate list of posts from the files in posts directory
- [x] Create a template for the index page
- [x] Generate the index page with the list of posts
- [ ] Add created and updated information to the individual posts
- [ ] Create a contact page template
- [x] Create a projects page template
- [x] SCP files from local to remote
- [x] Create and generate all the listings using templates
- [x] Parse markdown to html
- [ ] Add provision to exclude files in .scpconfig
