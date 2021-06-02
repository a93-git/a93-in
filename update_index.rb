require 'nokogiri'

if (ARGV[0] == nil)
  puts "Filepath is required. No filepath provided. Exiting"
  exit
else
  PATH = ARGV[0].chomp
end

if Dir.open(PATH)
  files = Dir.open(PATH).children
  files.each do |file|
    nokogiri_doc = Nokogiri::HTML(File.open("#{PATH}/#{file}"))
    h1_tag = nokogiri_doc.xpath("//h1")
    puts post_title = h1_tag[0].to_s.sub("<h1>", "").sub("</h1>", "").strip
  end
end

