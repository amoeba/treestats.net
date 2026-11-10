require_relative '../story_helper'

describe 'NewsFeedStory' do
  before { NewsPost.delete_all }
  after { NewsPost.delete_all }

  def read_feed
    get '/news.atom'
    assert_equal 200, last_response.status
    assert_equal 'application/atom+xml;charset=utf-8', last_response.headers['Content-Type']
    document = Nokogiri::XML(last_response.body) { |config| config.strict.nonet }
    assert_equal 'feed', document.root.name
    assert_equal 'http://www.w3.org/2005/Atom', document.root.namespace.href
    assert_equal 'https://treestats.net/', document.root['xml:base']
    document.remove_namespaces!
  end

  it 'serves a valid, stable empty feed without the page layout' do
    feed = read_feed
    assert_empty feed.xpath('/feed/entry')
    assert_equal 'TreeStats News', feed.at_xpath('/feed/title').text
    assert_equal 'TreeStats', feed.at_xpath('/feed/author/name').text
    assert_equal 'https://treestats.net/news', feed.at_xpath('/feed/id').text
    assert_equal 'https://treestats.net/news.atom', feed.at_xpath('/feed/link[@rel="self"]')['href']
    assert_equal 'https://treestats.net/news', feed.at_xpath('/feed/link[@rel="alternate"]')['href']
    Time.iso8601(feed.at_xpath('/feed/updated').text)
    refute_includes last_response.body, '<html'
    original = last_response.body
    read_feed
    assert_equal original, last_response.body
  end

  it 'includes only the latest twenty published posts, newest first' do
    posts = 22.times.map do |i|
      NewsPost.create!(title: "Announcement #{i}", body: 'Published body', status: 'published', published_at: Time.utc(2020, 1, i + 1))
    end
    NewsPost.create!(title: 'Draft announcement', body: 'Secret draft')
    # Guard against accidentally exposing future documents, even if inserted outside the editor.
    NewsPost.collection.insert_one(title: 'Future announcement', body: 'Secret future', status: 'published',
      slug: 'future-announcement', published_at: Time.now + 3600)

    feed = read_feed
    assert_equal posts.last(20).reverse.map(&:title), feed.xpath('/feed/entry/title').map(&:text)
    refute_includes last_response.body, 'Secret draft'
    refute_includes last_response.body, 'Secret future'
    assert_equal posts.last.published_at.utc.iso8601, feed.at_xpath('/feed/entry/published').text
  end

  it 'escapes XML, includes safe full HTML content, and preserves entry IDs when edited' do
    post = NewsPost.create!(title: 'News <today> & "tomorrow" — Dereth',
      body: 'Hello **Dereth**. [Archive](/news) <script>alert(1)</script>',
      status: 'published', published_at: Time.utc(2020), updated_at: Time.utc(2021))
    feed = read_feed
    entry = feed.at_xpath('/feed/entry')
    id = entry.at_xpath('id').text
    assert_equal "https://treestats.net/news/#{post.slug}", id
    assert_equal id, entry.at_xpath('link')['href']
    assert_equal post.title, entry.at_xpath('title').text
    content = entry.at_xpath('content')
    assert_equal 'html', content['type']
    assert_empty content.element_children
    html = Nokogiri::HTML.fragment(content.text)
    assert_equal 'Dereth', html.at_css('strong').text
    assert_equal '/news', html.at_css('a')['href']
    assert_empty html.css('script')

    post.update!(title: 'Renamed announcement', body: 'Edited content', updated_at: Time.utc(2022))
    feed = read_feed
    assert_equal id, feed.at_xpath('/feed/entry/id').text
    assert_equal 'Renamed announcement', feed.at_xpath('/feed/entry/title').text
    assert_includes feed.at_xpath('/feed/entry/content').text, 'Edited content'
    assert_equal post.reload.updated_at.utc.iso8601, feed.at_xpath('/feed/entry/updated').text
    assert_equal feed.at_xpath('/feed/entry/updated').text, feed.at_xpath('/feed/updated').text
    assert_equal Time.utc(2020).iso8601, feed.at_xpath('/feed/entry/published').text

    post.update!(status: 'draft')
    assert_empty read_feed.xpath('/feed/entry')
  end

  it 'advertises the feed in page heads and links to it from home and the archive' do
    post = NewsPost.create!(title: 'Public news', body: 'Published body', status: 'published', published_at: Time.utc(2020))
    ['/', '/news', "/news/#{post.slug}"].each do |path|
      get path
      assert_equal 200, last_response.status
      page = Nokogiri::HTML(last_response.body)
      link = page.at_css('head link[rel="alternate"][type="application/atom+xml"]')
      refute_nil link
      assert_equal '/news.atom', link['href']
      assert_equal 'TreeStats News', link['title']
      refute_nil page.at_css('body a[href="/news.atom"]') if ['/', '/news'].include?(path)
    end
  end
end
