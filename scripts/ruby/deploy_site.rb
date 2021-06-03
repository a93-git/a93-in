require 'net/scp'
require 'json'

BASE_DIR = $0.split("/")[0..-2].join("/")
load "#{BASE_DIR}/parse_markdown.rb"

# Read the configuration JSON file
fh = File.open(".scpconfig.json")
config_json = JSON.parse(fh.read)

scp_paths = config_json["scp"]
scp_exclude_paths = config_json["exclude"]
markdown_paths = config_json["markdown_paths"]

# Generate the templates into HTML files
puts "Generating the static files from templates..."
`ruby scripts/ruby/generate_post_link.rb projects/ templates/projects.html.erb projects.html`
`ruby scripts/ruby/generate_post_link.rb posts/ templates/index.html.erb index.html`
puts "Static file generation complete..."

puts ""

# Generating HTML from markdown files
puts "Generating HTML from markdown files..."
markdown_paths.each do |path|
  dir = Dir.open(path).children # Array of all the files in the path

  dir.each do |file|
    # Only parse the files that end with .md
    unless /\w*.md/.match(file) == nil
      ht = ParseMarkdown.get_parser.render(File.open("#{path}/#{file}").read) 
      filename = "#{path}/#{file.split(".")[0]}.html" 

      puts "Parsing #{file}"
      # providing a code block ensures that we are automatically closing the 
      # opened file. So, no need to close explicitly. 
      # File::CREAT -> create the file if doesn't exist
      # File::WRONLY -> open the file in write-only mode
      # See man page for open for the modes and Ruby's doc for File.open at 
      # https://ruby-doc.org/core-2.5.0/File.html#method-c-open
      # 00744 -> owner can rwx, others can read
      File.open(filename, File::CREAT | File::WRONLY, 00744) do |fh|
        fh.write(ht)
      end
    end
  end
end
puts "Done generating HTML from markdown files..."

puts ""

# This function recursively lists the files in the directory provided
# If the first path provided is a file, the same path is returned
def rec_listing(path, file_list)
  Dir.open(path).children.each do |child|
    filepath = "#{path}/#{child}"
    if File.directory?(filepath)
      rec_listing(filepath, file_list)
    else
      file_list << filepath if /\.md/.match(filepath) == nil
    end
  end
  file_list
rescue  Errno::ENOTDIR => e
  puts "#{path} is not a directory. Returning the same path"
  [path]
rescue Exception => e
  puts e.message
  puts e.class
  raise
end

# This array carries individual local and remote file paths 
files_to_scp = []
# For each path and destination line in the configfile
scp_paths.each do |line|
  x = []
  path = line.split  
  # We are getting the list of files eligible for transfer
  begin
    rec_listing(path[0], x).each do |i|
      # Re-creating the space separated format of source and destination
      # The remote path contains the exact destination of each file
      m = "#{i} #{path[1]}/#{i}"
      files_to_scp << m
    end
  rescue NoMethodError => e
    puts "Skipping #{path[0]} as it is not a directory"
  end
end

### TODO It won't copy the files to correct location on webserver
### TODO The folder structure needs to be updated for destination as well

puts ""

# scp files from local to remote system
puts "Copying files to the webserver"

transfer = {}

Net::SCP.start("a93", "abhishek") do |scp|
  files_to_scp.each do |line|
    puts line
    path = line.split

    # The file transfer is in blocking fashion
    # Using asynchronous version (removing the ! from the method name will 
    # cause it to throw an Exception
    scp.upload!(path[0], path[1], :recursive => true) do |ch, name, sent, total|
      transfer[name] = "#{sent}/#{total}"
      print "#{name}: #{sent}/#{total}                 "
      STDOUT.goto_column(0)
    end
  end
end

STDOUT.erase_line(2)
puts "" 

puts "Transfer complete"
puts "Transfer status by file..."
transfer.each do |k, v|
  puts "#{k}\t\t\t=> #{v}"
end
