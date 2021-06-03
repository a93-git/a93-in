require 'nokogiri'
require 'erb'

BASE_DIR = $0.split("/")[0..-2].join("/")
load "#{BASE_DIR}/generate.rb"

if (ARGV[0] == nil or ARGV[1] == nil or ARGV[2] == nil)
  puts "Directory path and template file and the file to update are reuiqred"
  puts "Missing required arguments"
  puts "Usage: ruby generate_post_link.rb <dir with posts> <template> <file to generate>"
  exit
else
  PATH = ARGV[0].chomp
  TEMPLATE = ARGV[1].chomp
  FILE_TO_GEN = ARGV[2].chomp
end

gl = GenerateList.new(PATH).get_html_list
fh = File.open(TEMPLATE)
template = ERB.new(fh.read)

File.open(FILE_TO_GEN, File::RDWR|File::CREAT, 0644) do |fh|
  fh.write(template.result)
end
