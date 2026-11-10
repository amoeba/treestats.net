require_relative '../story_helper'

# Outer BDD loop: exercise the real login, forms, persistence and public routes.
describe 'NewsStory' do
  before do
    AdminUser.delete_all
    redis.del('admin:login:attempts:127.0.0.1')
    NewsPost.delete_all if defined?(NewsPost)
  end

  after do
    NewsPost.delete_all if defined?(NewsPost)
  end

  def csrf
    last_response.body[/name="authenticity_token"[^>]*value="([^"]+)"/, 1]
  end

  def sign_in
    user = AdminUser.where(name: 'news-admin').first || AdminUser.new(name: 'news-admin')
    user.password = 'correct-horse-battery'
    user.save!
    get '/admin/login'
    token = csrf
    real_now = Time.method(:now)
    future = real_now.call + 2
    begin
      Time.define_singleton_method(:now) { future }
      post '/admin/login', name: user.name, password: 'correct-horse-battery', authenticity_token: token
    ensure
      Time.define_singleton_method(:now, real_now)
    end
    assert_equal 302, last_response.status
  end

  def editor_fields(overrides = {})
    {title: 'A new chapter', body: 'Hello **Dereth**. [Visit](https://treestats.net)',
     published_at: '2020-01-02T03:04', action: 'save', authenticity_token: csrf}.merge(overrides)
  end

  it 'hides all management routes from anonymous visitors and rejects writes without CSRF' do
    %w[/admin/news /admin/news/new /admin/news/000000000000000000000001/edit].each do |path|
      get path
      assert_equal 404, last_response.status
    end
    paths = %w[/admin/news /admin/news/preview /admin/news/000000000000000000000001 /admin/news/000000000000000000000001/preview]
    paths.each do |path|
      post path
      assert_equal 404, last_response.status
    end
    sign_in
    paths.each do |path|
      post path, authenticity_token: 'wrong'
      assert_equal 403, last_response.status
    end
  end

  it 'preserves invalid fields, rejects future or malformed dates, and permits a blank date on publish' do
    sign_in
    get '/admin/news/new'
    token = csrf
    ['not-a-date', '2020-02-31T00:00', (Time.now.utc + 3600).strftime('%Y-%m-%dT%H:%M')].each do |date|
      post '/admin/news', editor_fields(published_at: date, action: 'publish', authenticity_token: token)
      assert_equal 422, last_response.status
      assert_includes last_response.body, 'A new chapter'
      assert_includes last_response.body, 'value="publish"'
      assert_equal 0, NewsPost.count
    end
    post '/admin/news', editor_fields(title: '', authenticity_token: token)
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'Title'
    post '/admin/news', editor_fields(published_at: '', action: 'publish', authenticity_token: token)
    assert_equal 302, last_response.status
    assert_in_delta Time.now.to_f, NewsPost.first.published_at.to_f, 5
  end

  it 'shows only the latest five titles at home and paginates the published archive' do
    posts = 22.times.map do |i|
      NewsPost.create!(title: "Announcement #{i}", body: 'Secret body text', status: 'published', published_at: Time.utc(2020, 1, i + 1))
    end
    NewsPost.create!(title: 'Draft announcement', body: 'Not public')
    get '/'
    links = Nokogiri::HTML(last_response.body).css('.news-dashboard tbody a')
    assert_equal posts.last(5).reverse.map(&:title), links.map(&:text)
    dates = Nokogiri::HTML(last_response.body).css('.news-dashboard time')
    assert_equal posts.last(5).reverse.map { |post| post.published_at.utc.strftime('%Y-%m-%d') }, dates.map(&:text)
    assert_equal posts.last.published_at.utc.iso8601, dates.first['datetime']
    assert_equal '2020-01-22 00:00 UTC', dates.first['title']
    refute_includes last_response.body, 'Secret body text'
    get '/news'
    assert_equal 200, last_response.status
    archive = Nokogiri::HTML(last_response.body)
    assert_equal 'Title', archive.at_css('.news-archive th').text
    refute_includes last_response.body, 'Updates from TreeStats.'
    assert_equal 20, archive.css('.news-archive tbody a').length
    assert_includes last_response.body, '/news?page=2'
    refute_includes last_response.body, 'Draft announcement'
    get '/news?page=2'
    assert_equal posts.first(2).reverse.map(&:title), Nokogiri::HTML(last_response.body).css('.news-archive tbody a').map(&:text)
    %w[0 -1 abc 1000000].each do |page|
      get "/news?page=#{page}"
      assert_equal 404, last_response.status
    end
  end

  it 'returns useful empty states and 404s for unknown or draft URLs, with no deletion endpoint' do
    get '/'
    assert_includes last_response.body, 'No news posts yet.'
    get '/news'
    assert_includes last_response.body, 'No news posts yet.'
    draft = NewsPost.create!(title: 'Previously published', body: 'Not public', slug: 'hidden')
    %w[hidden nonexistent].each do |slug|
      get "/news/#{slug}"
      assert_equal 404, last_response.status
    end
    sign_in
    get '/admin/news'
    assert_includes last_response.headers['Cache-Control'], 'no-store'
    assert_includes last_response.body, draft.title
    refute_includes last_response.body, 'All announcements are published as TreeStats.'
    %w[invalid-id 000000000000000000000001].each do |id|
      get "/admin/news/#{id}/edit"
      assert_equal 404, last_response.status
    end
    delete "/admin/news/#{draft.id}"
    assert_equal 404, last_response.status
    assert NewsPost.where(id: draft.id).exists?
  end

  it 'previews unsaved edits safely without changing the published version' do
    announcement = NewsPost.create!(title: 'Original', body: 'Original body', status: 'published', published_at: Time.utc(2020))
    sign_in
    get "/admin/news/#{announcement.id}/edit"
    post "/admin/news/#{announcement.id}/preview", editor_fields(title: '<script>bad</script>', body: '**Preview only** <script>bad</script>')
    assert_equal 200, last_response.status
    assert_includes last_response.body, '<strong>Preview only</strong>'
    refute_includes last_response.body, 'By TreeStats'
    refute_includes last_response.body, '<script>bad</script>'
    assert_includes last_response.body, 'value="&lt;script&gt;bad&lt;/script&gt;"'
    assert_equal 'Original body', announcement.reload.body
    assert_equal 'Original', announcement.title
  end

  it 'lets an admin draft, preview, publish, edit and unpublish an announcement' do
    sign_in
    get '/admin'
    assert_includes last_response.body, 'href="/admin/news"'
    get '/admin/news/new'
    assert_equal 200, last_response.status
    fields = editor_fields

    post '/admin/news/preview', fields
    assert_equal 200, last_response.status
    assert_includes last_response.body, '<strong>Dereth</strong>'
    assert_equal 0, NewsPost.count

    post '/admin/news', fields
    assert_equal 302, last_response.status
    announcement = NewsPost.first
    assert_equal 'draft', announcement.status
    get '/'
    refute_includes last_response.body, 'A new chapter'
    get '/news'
    refute_includes last_response.body, 'A new chapter'

    get "/admin/news/#{announcement.id}/edit"
    post "/admin/news/#{announcement.id}", editor_fields(action: 'publish')
    assert_equal 302, last_response.status
    announcement.reload
    assert_equal 'a-new-chapter', announcement.slug
    slug = announcement.slug

    # Anonymous readers can follow the homepage title to the complete post.
    clear_cookies
    get '/'
    assert_includes last_response.body, "href=\"/news/#{slug}\""
    refute_includes last_response.body, 'Hello'
    get "/news/#{slug}"
    assert_equal 200, last_response.status
    assert_includes last_response.body, '<strong>Dereth</strong>'
    refute_includes last_response.body, 'By TreeStats'
    assert_includes last_response.body, '2020-01-02'

    sign_in
    get "/admin/news/#{announcement.id}/edit"
    post "/admin/news/#{announcement.id}", editor_fields(title: 'A renamed chapter', body: 'Updated announcement')
    assert_equal 302, last_response.status
    assert_equal slug, announcement.reload.slug
    get "/news/#{slug}"
    assert_includes last_response.body, 'Updated announcement'

    get "/admin/news/#{announcement.id}/edit"
    post "/admin/news/#{announcement.id}", editor_fields(action: 'unpublish')
    assert_equal 302, last_response.status
    clear_cookies
    get "/news/#{slug}"
    assert_equal 404, last_response.status
    get '/'
    refute_includes last_response.body, "href=\"/news/#{slug}\""
  end
end
