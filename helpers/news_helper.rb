require 'time'
require_relative '../lib/news_markdown'

module NewsHelper
  NEWS_PAGE_SIZE = 20

  def news_page
    value = params.fetch('page', '1').to_s
    halt 404 unless value.match?(/\A[1-9]\d{0,5}\z/)
    value.to_i
  end

  def find_news_post!
    id = params['id'].to_s
    halt 404 unless BSON::ObjectId.legal?(id)
    NewsPost.where(id: id).first || halt(404)
  end

  def prepare_news_form
    @editor_published = @post.published?
    @publication_input = @post.published_at&.utc&.strftime('%Y-%m-%dT%H:%M:%S')
  end

  def apply_news_fields
    @editor_published = @post.published?
    @post.title = params['title'].to_s.strip
    @post.body = params['body'].to_s
    @publication_input = params['published_at'].to_s.strip
    @date_error = false
    if @publication_input.empty?
      @post.published_at = nil
    else
      begin
        # datetime-local is deliberately labelled UTC, not the browser's timezone.
        raise ArgumentError unless @publication_input.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?\z/)
        parsed = DateTime.iso8601(@publication_input + 'Z')
        @post.published_at = parsed.to_time.utc
      rescue ArgumentError
        @post.published_at = nil
        @date_error = true
      end
    end
  end

  def save_news_post
    apply_news_fields
    action = params['action'].to_s
    halt 422, 'Unknown news action.' unless %w[save publish unpublish].include?(action)
    if action == 'publish'
      @post.status = 'published'
      @post.published_at ||= Time.now if @publication_input.empty?
    elsif action == 'unpublish'
      @post.status = 'draft'
    end

    valid = @post.valid?
    @post.errors.add(:published_at, 'must be a valid UTC date and time') if @date_error
    if valid && !@date_error && @post.save
      redirect "/admin/news/#{@post.id}/edit"
    else
      status 422
      haml :admin_news_form, layout: :admin_news_layout
    end
  rescue Mongo::Error::OperationFailure => error
    raise unless error.code == 11000
    @post.errors.add(:base, 'Another post used this URL. Please save again.')
    @post.slug = nil if @post.new_record? || !@post.slug_was
    status 422
    haml :admin_news_form, layout: :admin_news_layout
  end
end
