require 'nokogiri'

if (ARGV[0] == nil)
  puts "Filepath is required. No filepath provided. Exiting"
  exit
else
  PATH = ARGV[0].chomp
end

links = []

if Dir.open(PATH)
  files = Dir.open(PATH).children
  files.each do |file|
    # Read the document
    path = "#{PATH}#{file}"
    nokogiri_doc = Nokogiri::HTML(File.open(path))
    # Search for and find the title
    h1_tag = nokogiri_doc.xpath("//h1")
    post_title = h1_tag[0].to_s.sub("<h1>", "").sub("</h1>", "").strip
    # Create the html to insert
    link = "<p><a href=#{path}>#{post_title}</a></p>"
    links << link
  end
end

puts "Looking for index.html in current directory"
index_file = Dir.glob("index.html")[0]
if index_file != nil 
  puts "Found index.html"
  puts index_file
else
  puts "Couldn't find index.html. Please spcify a path: "
  index_file = gets.chomp
end

puts links

# Write the data to a separate html file
File.open("post_links.html", File::RDWR|File::CREAT, 0644) do |fh|
  links.each do |l|
    # Get an exclusive lock to the current file
    fh.flock(File::LOCK_EX)
    fh.write("#{l}\n")
  end
end
