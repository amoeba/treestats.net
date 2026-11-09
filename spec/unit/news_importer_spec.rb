require_relative '../spec_helper'
require_relative '../../lib/news_importer'
require 'stringio'
require 'open3'
require 'rbconfig'

# Only synthetic fixtures are written to the test database. The historical
# dataset is validated in memory; the real import is an operator-only action.
describe NewsImporter do
  before { NewsPost.delete_all }
  after { NewsPost.delete_all }

  def entries
    [{ 'legacy_id' => 'test-legacy-1', 'title' => 'Fixture announcement',
       'body' => 'A **fixture** with a [link](/about).', 'published_at' => '2020-01-02T03:04:00Z' }]
  end

  it 'provides CLI help and rejects invalid arguments without loading the application' do
    script = File.expand_path('../../scripts/admin/import-news.rb', __dir__)
    output, status = Open3.capture2e(RbConfig.ruby, script, '--help')
    assert status.success?, output
    assert_includes output, '--apply'
    output, status = Open3.capture2e(RbConfig.ruby, script, '--unknown')
    refute status.success?
    assert_includes output, 'invalid option'
    output, status = Open3.capture2e(RbConfig.ruby, script, '--file', '/nonexistent/news.json')
    refute status.success?
    assert_includes output, 'No such file'
  end

  it 'reports a dry run without writing posts' do
    output = StringIO.new
    NewsImporter.new(entries).run(dry_run: true, output: output)
    assert_equal 0, NewsPost.count
    assert_includes output.string, 'Would import: Fixture announcement'
  end

  it 'imports published fixtures with original UTC dates and skips existing entries without overwriting edits' do
    importer = NewsImporter.new(entries)
    importer.run(output: StringIO.new)
    post = NewsPost.first
    assert_equal 'published', post.status
    assert_equal Time.utc(2020, 1, 2, 3, 4), post.published_at
    assert_equal entries.first['body'], post.body
    post.update!(title: 'Admin edited', status: 'draft')
    output = StringIO.new
    importer.run(output: output)
    assert_equal 1, NewsPost.count
    assert_equal 'Admin edited', post.reload.title
    assert_equal 'draft', post.status
    assert_includes output.string, 'Skipped'
  end

  it 'validates the entire input before writing anything' do
    invalid = entries + [entries.first.merge('legacy_id' => 'bad', 'body' => '')]
    assert_raises(NewsImporter::Error) { NewsImporter.new(invalid).run(output: StringIO.new) }
    assert_equal 0, NewsPost.count
    assert_raises(NewsImporter::Error) { NewsImporter.new(entries * 2).run(output: StringIO.new) }
  end

  it 'preserves all 17 historical entries and validates them without importing' do
    data = JSON.parse(File.read(File.expand_path('../../data/legacy_news.json', __dir__)))
    assert_equal 17, data.length
    assert_equal '2023-12-26T22:00:00Z', data.first['published_at']
    assert_equal '2015-12-29T05:00:00Z', data.last['published_at']
    assert_equal 'TreeStats update — February 23, 2016', data.find { |entry| entry['legacy_id'] == 'homepage-201602231600' }['title']
    assert_includes data.first['body'], '[Dokku](https://dokku.com/)'
    NewsImporter.new(data).validate!
    assert_equal 0, NewsPost.count
  end
end
