require_relative '../spec_helper'
require_relative '../../lib/news_markdown'

describe NewsMarkdown do
  it 'renders paragraphs, lists, links, emphasis and code' do
    html = NewsMarkdown.render("Hello **Dereth**\n\n- `code`\n- [Visit](https://treestats.net)")
    assert_includes html, '<strong>Dereth</strong>'
    assert_includes html, '<ul>'
    assert_includes html, '<code>code</code>'
    assert_includes html, 'href="https://treestats.net"'
  end

  it 'disables raw HTML and removes unsafe link protocols' do
    html = NewsMarkdown.render('<script>alert(1)</script><img src=x onerror=alert(1)>' + "\n\n[bad](javascript:alert%281%29)\n\n[bad](data:text/html,hello)")
    refute_includes html, '<script'
    refute_includes html, '<img'
    refute_includes html, 'href="javascript:'
    refute_includes html, 'href="data:'
  end
end
