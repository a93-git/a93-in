require 'nokogiri'

class GenerateList
  attr_reader :filepath

  def initialize(filepath)
    @filepath = filepath
  end

  def get_html_list
    generate_html_list
  end

  # def write_to_file(filepath)
    # # Write the data to a separate html file
    # File.open("post_links.html", File::RDWR|File::CREAT, 0644) do |fh|
      # post_links.each do |link|
        # # Get an exclusive lock to the current file
        # fh.flock(File::LOCK_EX)
        # fh.write("#{link}\n")
      # end
    # end
  # end

  def generate_html_list
    post_links = []
    if Dir.open(filepath)
      files = Dir.open(filepath).children
      files.each do |file|
        # Read the document
        path = "#{PATH}#{file}"
        nokogiri_doc = Nokogiri::HTML(File.open(path))
        # Search for and find the title
        # The first h1 tag is taken as the title
        h1_tag = nokogiri_doc.xpath("//h1")
        post_title = h1_tag[0].to_s.sub("<h1>", "").sub("</h1>", "").strip
        # Create the html to insert
        link = "<p><a href=#{path}>#{post_title}</a></p>"
        post_links << link
      end
    end
    post_links
  end

  private :generate_html_list
end

