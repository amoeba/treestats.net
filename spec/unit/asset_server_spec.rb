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
      File.write(File.join(@tmpdir, 'public', 'assets', 'app-abc123.css'), 'body{}')
      File.write(File.join(@tmpdir, 'public', 'assets', 'manifest.json'),
        JSON.generate({ '/app.css' => '/app-abc123.css' }))
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
      status, headers, body = @server.call('PATH_INFO' => '/app-abc123.css')
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

  describe 'precompile' do
    it 'fingerprints files, copies them, and writes manifest.json' do
      tmpdir = Dir.mktmpdir
      FileUtils.mkdir_p(File.join(tmpdir, 'assets', 'stylesheets'))
      FileUtils.mkdir_p(File.join(tmpdir, 'assets', 'javascripts'))
      FileUtils.mkdir_p(File.join(tmpdir, 'assets', 'images'))
      File.write(File.join(tmpdir, 'assets', 'stylesheets', 'application.css'), 'body{}')
      File.write(File.join(tmpdir, 'assets', 'javascripts', 'app.js'), 'var x=1;')
      File.write(File.join(tmpdir, 'assets', 'images', 'logo.png'), 'PNG')

      AssetServer.precompile(tmpdir)

      output_dir = File.join(tmpdir, 'public', 'assets')
      manifest_path = File.join(output_dir, 'manifest.json')
      assert File.exist?(manifest_path), 'manifest.json should exist'

      manifest = JSON.parse(File.read(manifest_path))
      assert manifest.key?('/application.css'), 'manifest should include application.css'
      assert manifest.key?('/app.js'), 'manifest should include app.js'
      assert manifest.key?('/logo.png'), 'manifest should include logo.png'

      manifest.each_value do |fingerprinted|
        assert File.exist?(File.join(output_dir, fingerprinted)), "#{fingerprinted} should exist on disk"
      end
    ensure
      FileUtils.rm_rf(tmpdir)
    end

    it 'wipes only public/assets, not the whole public dir' do
      tmpdir = Dir.mktmpdir
      FileUtils.mkdir_p(File.join(tmpdir, 'assets', 'stylesheets'))
      File.write(File.join(tmpdir, 'assets', 'stylesheets', 'application.css'), 'body{}')
      FileUtils.mkdir_p(File.join(tmpdir, 'public'))
      sentinel = File.join(tmpdir, 'public', 'favicon.ico')
      File.write(sentinel, 'ico')

      AssetServer.precompile(tmpdir)

      assert File.exist?(sentinel), 'public/favicon.ico should be untouched'
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
