require_relative '../spec_helper'

describe NewsPost do
  before { NewsPost.delete_all }
  after { NewsPost.delete_all }

  def post_attributes
    {title: 'Hello, Dereth!', body: 'Welcome **back**', status: 'published', published_at: Time.utc(2020, 1, 1)}
  end

  it 'validates required content, status and manual publication dates' do
    post = NewsPost.new
    refute post.valid?
    assert post.errors[:title].any?
    assert post.errors[:body].any?
    post.assign_attributes(post_attributes.merge(status: 'scheduled'))
    refute post.valid?
    post.assign_attributes(status: 'published', published_at: nil)
    refute post.valid?
    post.published_at = Time.now + 3600
    refute post.valid?
    post.published_at = Time.now - 60
    assert post.valid?
  end

  it 'assigns unique slugs at first publication and keeps them through edits and unpublishing' do
    draft = NewsPost.create!(title: 'Hello, Dereth!', body: 'Draft')
    assert_nil draft.slug
    first = NewsPost.create!(post_attributes)
    second = NewsPost.create!(post_attributes)
    assert_equal 'hello-dereth', first.slug
    refute_equal first.slug, second.slug
    first.update!(title: 'Different title', status: 'draft')
    assert_equal 'hello-dereth', first.reload.slug
    assert_equal Time.utc(2020, 1, 1), first.published_at
    draft.update!(status: 'published', published_at: Time.utc(2020, 1, 2))
    refute_nil draft.slug
  end

  it 'supports titles with no ASCII letters and enforces unique database indexes' do
    post = NewsPost.create!(post_attributes.merge(title: '新しいニュース'))
    assert_match(/\A[a-z0-9-]+\z/, post.slug)
    NewsPost.ensure_indexes!
    assert_raises(Mongo::Error::OperationFailure) do
      NewsPost.collection.insert_one(title: 'Duplicate', slug: post.slug)
    end
  end

  it 'orders only published posts by publication date rather than last edit' do
    old = NewsPost.create!(post_attributes)
    recent = NewsPost.create!(post_attributes.merge(published_at: Time.utc(2021, 1, 1)))
    NewsPost.create!(title: 'Hidden', body: 'Draft')
    old.update!(body: 'Edited today')
    assert_equal [recent.id, old.id], NewsPost.published.map(&:id)
  end
end
