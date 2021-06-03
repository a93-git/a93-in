require 'net/scp'
require 'json'

BASE_DIR = $0.split("/")[0..-2].join("/")
load "#{BASE_DIR}/parse_markdown.rb"
load "#{BASE_DIR}/generate_file_tree.rb"

# Read the configuration JSON file
fh = File.open(".scpconfig.json")
config_json = JSON.parse(fh.read)
scp_paths = config_json["scp"]
scp_exclude_paths = config_json["exclude"]
markdown_paths = config_json["markdown_paths"]
webserver_path = config_json["webserver"]
fh.close

# Generate the templates into HTML files
puts "Generating the static files from templates..."
`ruby scripts/ruby/generate_post_link.rb html/projects/ templates/projects.html.erb projects.html`
`ruby scripts/ruby/generate_post_link.rb html/posts/ templates/index.html.erb index.html`
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
puts "Done generating HTML from markdown files...", ""

generator = GenerateFileTree.new("", scp_exclude_paths)

# For each path and destination line in the configfile
scp_paths.each do |path|
  # We are getting the list of files eligible for transfer
  begin
    generator.rec_listing(path)
  rescue NoMethodError => e
    puts "Skipping #{path[0]} as it couldn't be parsed", ""
  rescue Exception => e
    puts e.message, e.class, ""
  end
end

files_to_scp = generator.file_list

count = 0
while count < files_to_scp.count
  files_to_scp[count] = "#{files_to_scp[count]} #{webserver_path}/#{files_to_scp[count]}"
  count += 1
end
puts files_to_scp

puts ""

# Create remote folders that don't exist
puts "Initiating remote connection..."
Net::SSH.start("a93", "abhishek") do |ssh|
  puts "Delete any files existing in the webserver's root"
  output = ssh.exec!("find #{webserver_path} -type f -print0 | xargs -0 /bin/rm -f")
  puts "Output of file deletion on webserver", output, ""

  puts "Current files at webserver root path on remote server"
  output = ssh.exec!("ls -la #{webserver_path}")
  puts output, ""
  
  puts "Checking for remote folders..."
  checked = []
  # A path once checked won't be checked again
  files_to_scp.each do |file|
    path = file.split[1].split("/")[0..-2].join("/") 
    unless checked.include?(path)
      puts "Checking if #{path} exists on remote server. If not it will be created"
      ssh.exec!("mkdir -p #{path}")
      checked << path 
    end
  end

  puts "Changing the ownership of files"
  output = ssh.exec!("sudo chown -R $USER:$USER #{webserver_path}; ls -laR #{webserver_path}")
  puts output, "Done", ""
end
puts "Done checking for remote folders", ""

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
