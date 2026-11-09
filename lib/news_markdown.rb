require 'redcarpet'
require 'sanitize'

module NewsMarkdown
  def self.render(source)
    renderer = Redcarpet::Render::HTML.new(escape_html: true, safe_links_only: true)
    markdown = Redcarpet::Markdown.new(renderer, fenced_code_blocks: true, no_intra_emphasis: true)
    Sanitize.fragment(markdown.render(source.to_s), Sanitize::Config::BASIC)
  end
end
