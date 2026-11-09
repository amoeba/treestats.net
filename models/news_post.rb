class NewsPost
  include Mongoid::Document
  include Mongoid::Timestamps

  field :title, type: String
  field :body, type: String
  field :status, type: String, default: 'draft'
  field :published_at, type: Time
  field :slug, type: String
  field :legacy_id, type: String

  index({slug: 1}, {unique: true, partial_filter_expression: {slug: {'$type' => 'string'}}})
  index({legacy_id: 1}, {unique: true, partial_filter_expression: {legacy_id: {'$type' => 'string'}}})
  index({status: 1, published_at: -1, _id: -1})

  validates :title, presence: true, length: {maximum: 200}
  validates :body, presence: true, length: {maximum: 100_000}
  validates :status, inclusion: {in: %w[draft published]}
  validates :published_at, presence: true, if: :published?
  validates :slug, uniqueness: true, allow_nil: true
  validate :publication_is_not_in_the_future

  before_validation :assign_public_slug
  before_create { self.class.ensure_indexes! }

  scope :published, -> { where(status: 'published', :published_at.lte => Time.now).order_by(published_at: :desc, _id: :desc) }

  def self.ensure_indexes!
    # Also callable by the deployment/import tools; unique indexes are enforced
    # by MongoDB, not just application-level validation.
    create_indexes
  end

  def published?
    status == 'published'
  end

  private

  def publication_is_not_in_the_future
    errors.add(:published_at, 'cannot be in the future (publication is manual)') if published_at && published_at > Time.now
  end

  def assign_public_slug
    return unless published? && slug.nil?

    base = title.to_s.unicode_normalize(:nfkd).encode('ASCII', invalid: :replace, undef: :replace, replace: '')
      .downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-|-\z/, '')
    base = 'treestats-update' if base.empty?
    self.slug = self.class.where(slug: base).exists? ? "#{base}-#{id}" : base
  end
end
