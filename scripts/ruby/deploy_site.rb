require 'net/scp'

BASE_DIR = $0.split("/")[0..-2].join("/")
load "#{BASE_DIR}/parse_markdown.rb"

# Generate the templates into HTML files
puts "Generating the static files from templates..."
`ruby scripts/ruby/generate_post_link.rb projects/ templates/projects.html.erb projects.html`
`ruby scripts/ruby/generate_post_link.rb posts/ templates/index.html.erb index.html`
puts "Static file generation complete..."

puts ""

# Generating HTML from markdown files
puts "Generating HTML from markdown files..."
path = "posts/"

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
puts "Done generating HTML from markdown files..."

# scp files from local to remote system
puts "Copying files to the webserver"
fh = File.open(".scpconfig")

transfer = {}

Net::SCP.start("a93", "abhishek") do |scp|
  fh.each_line do |line|
    puts line
    path = line.split
    scp.upload(path[0], path[1], :recursive => true) do |ch, name, sent, total|
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
