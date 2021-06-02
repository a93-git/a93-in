require 'redcarpet'

# Override the methods to add custom classes to the rendered HTML
# Will be poputlated over time
class CustomRender < Redcarpet::Render::HTML
end

# Exceptions
class NoPathError < Exception
end

parser = Redcarpet::Markdown.new(
  # Redcarpet::Render::HTML.new(escape_html: true, with_toc_data: true), 
  CustomRender.new(escape_html: true, with_toc_data: true), 
  autolink: true, # parse links not within <>
  tables: true, # parse tables
  no_intra_emphasis: true, # _ inside word is not parsed as em
  fenced_code_blocks: true, # use ``` for code
  disable_indented_code_blocks: true, # don't <code> the indented block
  strikethrough: true, # ~~word~~_ does strikethrough
  lax_spacing: false, # blocks should be separated by newline
  space_after_headers: true, # there should be space between # and text
  underline: true, # _word_ does underline
  highlight: true, # ==word== does highlighting
  quote: true, # "quote" looks like quote
  hardwrap: true,
  footnotes: true # a [^1]; [^]: footnote
)

begin
  if ARGV[0] == nil
    raise NoPathError, "A valid path is required"
  else
    path = ARGV[0].strip
  end
rescue NoPathError => e
  puts "#{e.message} -> #{e.class}"
  puts e.backtrace
  exit
end


dir = Dir.open(path).children # Array of all the files in the path

dir.each do |file|
  # Only parse the files that end with .md
  unless /\w*.md/.match(file) == nil
    ht = parser.render(File.open("#{path}/#{file}").read) 
    filename = "#{path}/#{file.split(".")[0]}.html" 

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

