require 'digest/md5'
require 'json'

class AssetServer
  CONTENT_TYPES = {
    '.css'  => 'text/css',
    '.js'   => 'application/javascript',
    '.jpg'  => 'image/jpeg',
    '.jpeg' => 'image/jpeg',
    '.png'  => 'image/png',
    '.gif'  => 'image/gif',
    '.ico'  => 'image/x-icon',
    '.svg'  => 'image/svg+xml',
    '.woff' => 'font/woff',
    '.woff2'=> 'font/woff2',
  }.freeze

  # manifest maps logical path -> fingerprinted path
  # e.g. "/application.css" -> "/application-abc123.css"
  # Empty in development — helper falls back to the unfingerprinted path.
  attr_reader :manifest

  def initialize(root)
    @root = root
    @manifest = {}
    load_manifest if production?
  end

  def call(env)
    path = env['PATH_INFO'].to_s.split('?').first
    production? ? serve_from_disk(path) : serve_dev(path)
  end

  def self.precompile(root)
    require 'fileutils'
    output_dir = File.join(root, 'public', 'assets')
    FileUtils.rm_rf(output_dir)
    FileUtils.mkdir_p(output_dir)

    manifest = {}

    copy_files(root, 'assets/stylesheets', '.css', output_dir, manifest)
    copy_files(root, 'assets/javascripts', '.js', output_dir, manifest)
    copy_files(root, 'assets/images', nil, output_dir, manifest)

    File.write(File.join(output_dir, 'manifest.json'), JSON.generate(manifest))
    puts "Wrote #{manifest.size} assets to #{output_dir}"
  end

  private

  def production?
    ENV['RACK_ENV'] == 'production'
  end

  def self.fingerprint(logical_path, digest)
    ext  = File.extname(logical_path)
    base = logical_path.chomp(ext)
    "#{base}-#{digest}#{ext}"
  end

  def load_manifest
    path = File.join(@root, 'public', 'assets', 'manifest.json')
    raise "manifest.json not found — run rake assets:precompile" unless File.exist?(path)
    @manifest = JSON.parse(File.read(path))
  end

  def serve_from_disk(fingerprinted_path)
    file_path = File.join(@root, 'public', 'assets', fingerprinted_path)
    return [404, {}, ['Not found']] unless File.exist?(file_path)

    body = File.binread(file_path)
    ext  = File.extname(fingerprinted_path)
    headers = {
      'Content-Type'  => CONTENT_TYPES.fetch(ext, 'application/octet-stream'),
      'Cache-Control' => 'public, max-age=31536000, immutable',
    }
    [200, headers, [body]]
  end

  def serve_dev(path)
    ext = File.extname(path)

    Dir.glob(File.join(@root, 'assets', '**', '*')).each do |file_path|
      next if File.directory?(file_path)
      next unless file_path.end_with?(path)
      return [200, { 'Content-Type' => CONTENT_TYPES.fetch(ext, 'application/octet-stream'), 'Cache-Control' => 'no-cache' }, [File.binread(file_path)]]
    end

    [404, {}, ['Not found']]
  end

  def self.copy_files(root, rel_dir, ext_filter, output_dir, manifest)
    dir = File.join(root, rel_dir)
    return unless File.directory?(dir)

    Dir.glob(File.join(dir, '**', '*')).each do |src|
      next if File.directory?(src)
      next if ext_filter && File.extname(src) != ext_filter

      body          = File.binread(src)
      logical       = '/' + src.sub("#{dir}/", '')
      digest        = Digest::MD5.hexdigest(body)
      fingerprinted = fingerprint(logical, digest)

      dest = File.join(output_dir, fingerprinted)
      FileUtils.mkdir_p(File.dirname(dest))
      File.binwrite(dest, body)
      manifest[logical] = fingerprinted
    end
  end
end
