require_relative '../spec_helper'
require './lib/asset_server'

describe AssetServer do
  def production_server(root)
    with_env('RACK_ENV' => 'production') { AssetServer.new(root) }
  end

  def development_server(root)
    with_env('RACK_ENV' => 'development') { AssetServer.new(root) }
  end

  describe 'serve_from_disk (production)' do
    before do
      @tmpdir = Dir.mktmpdir
      FileUtils.mkdir_p(File.join(@tmpdir, 'public', 'assets'))
      File.write(File.join(@tmpdir, 'public', 'assets', 'manifest.json'), '{}')
      @server = production_server(@tmpdir)
    end

    after { FileUtils.rm_rf(@tmpdir) }

    it 'rejects path traversal' do
      status, _, _ = with_env('RACK_ENV' => 'production') {
        @server.call('PATH_INFO' => '/../../../etc/passwd')
      }
      assert_equal 404, status
    end

    it 'blocks manifest.json' do
      status, _, _ = with_env('RACK_ENV' => 'production') {
        @server.call('PATH_INFO' => '/manifest.json')
      }
      assert_equal 404, status
    end

    it 'serves an existing asset' do
      File.write(File.join(@tmpdir, 'public', 'assets', 'app-abc123.css'), 'body{}')
      status, headers, body = with_env('RACK_ENV' => 'production') {
        @server.call('PATH_INFO' => '/app-abc123.css')
      }
      assert_equal 200, status
      assert_equal 'text/css', headers['content-type']
      assert_equal 'body{}', body.first
    end

    it 'returns 404 for missing asset' do
      status, _, _ = with_env('RACK_ENV' => 'production') {
        @server.call('PATH_INFO' => '/missing.css')
      }
      assert_equal 404, status
    end
  end

  describe 'load_manifest failure in production' do
    it 'raises when manifest.json is absent' do
      tmpdir = Dir.mktmpdir
      FileUtils.mkdir_p(File.join(tmpdir, 'public', 'assets'))
      assert_raises(RuntimeError) { production_server(tmpdir) }
    ensure
      FileUtils.rm_rf(tmpdir)
    end
  end

  describe 'serve_dev (development)' do
    before do
      @tmpdir = Dir.mktmpdir
      FileUtils.mkdir_p(File.join(@tmpdir, 'assets', 'stylesheets'))
      FileUtils.mkdir_p(File.join(@tmpdir, 'assets', 'images'))
      File.write(File.join(@tmpdir, 'assets', 'stylesheets', 'application.css'), 'body{}')
      File.write(File.join(@tmpdir, 'assets', 'images', 'icon.png'), 'PNG')
      @server = development_server(@tmpdir)
    end

    after { FileUtils.rm_rf(@tmpdir) }

    it 'serves a file by full logical path' do
      status, headers, body = with_env('RACK_ENV' => 'development') {
        @server.call('PATH_INFO' => '/stylesheets/application.css')
      }
      assert_equal 200, status
      assert_equal 'text/css', headers['content-type']
      assert_equal 'body{}', body.first
    end

    it 'returns 404 for unknown path' do
      status, _, _ = with_env('RACK_ENV' => 'development') {
        @server.call('PATH_INFO' => '/stylesheets/missing.css')
      }
      assert_equal 404, status
    end

    it 'disambiguates same-basename files in different subdirectories' do
      File.write(File.join(@tmpdir, 'assets', 'stylesheets', 'icon.png'), 'WRONG')
      status, _, body = with_env('RACK_ENV' => 'development') {
        @server.call('PATH_INFO' => '/images/icon.png')
      }
      assert_equal 200, status
      assert_equal 'PNG', body.first
    end
  end
end
