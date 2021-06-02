require 'redcarpet'


class ParseMarkdown
  # Override the methods to add custom classes to the rendered HTML
  # Will be poputlated over time
  class CustomRender < Redcarpet::Render::HTML
  end

  # Exceptions
  class NoPathError < Exception
  end

  class << self
    def get_parser
      Redcarpet::Markdown.new(
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
    end
  end
end


