require 'digest/sha2'
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
    @production = ENV['RACK_ENV'] == 'production'
    @production ? load_manifest : build_dev_manifest
  end

  def call(env)
    path = env['PATH_INFO'].to_s.split('?').first
    @production ? serve_from_disk(path) : serve_dev(path)
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

  def self.fingerprint(logical_path, digest)
    ext  = File.extname(logical_path)
    base = logical_path.chomp(ext)
    "#{base}-#{digest}#{ext}"
  end

  def load_manifest
    manifest_path = File.join(@root, 'public', 'assets', 'manifest.json')
    raise "manifest.json not found — run rake assets:precompile" unless File.exist?(manifest_path)
    @manifest = JSON.parse(File.read(manifest_path))

    @production_assets = {}
    safe_base = File.expand_path(File.join(@root, 'public', 'assets'))
    @manifest.each_value do |fingerprinted|
      file_path = File.expand_path(File.join(safe_base, fingerprinted))
      unless file_path.start_with?(safe_base + '/')
        warn "manifest entry #{fingerprinted} outside of assets directory, skipping"
        next
      end
      unless File.exist?(file_path)
        warn "manifest entry #{fingerprinted} missing from disk"
        next
      end
      ext = File.extname(fingerprinted)
      @production_assets[fingerprinted] = {
        file_path: file_path,
        headers: {
          'content-type'  => CONTENT_TYPES.fetch(ext, 'application/octet-stream'),
          'cache-control' => 'public, max-age=31536000, immutable',
        },
      }
    end
  end

  def serve_from_disk(fingerprinted_path)
    entry = @production_assets[fingerprinted_path]
    return [404, {}, ['Not found']] unless entry
    body = File.binread(entry[:file_path])
    [200, entry[:headers].merge('content-length' => body.bytesize.to_s), [body]]
  end

  def build_dev_manifest
    @dev_files = {}
    assets_root = File.join(@root, 'assets')
    Dir.glob(File.join(assets_root, '**', '*')).sort.each do |file_path|
      next if File.directory?(file_path)
      logical = '/' + file_path.sub("#{assets_root}/", '')
      basename_key = '/' + File.basename(logical)
      if @manifest.key?(basename_key)
        warn "Asset basename collision: #{basename_key} already maps to #{@manifest[basename_key]}, ignoring #{logical}"
      else
        @manifest[basename_key] = logical
      end
      @manifest[logical] = logical
      @dev_files[logical] = file_path
    end
  end

  def serve_dev(path)
    path = "/#{path.sub(%r{\A/+}, '')}"
    return [404, {}, ['Not found']] if path == '/'

    file_path = @dev_files[path]
    return [404, {}, ['Not found']] unless file_path

    ext = File.extname(path)
    body = File.binread(file_path)
    [200, { 'content-type' => CONTENT_TYPES.fetch(ext, 'application/octet-stream'), 'cache-control' => 'no-cache', 'content-length' => body.bytesize.to_s }, [body]]
  end

  def self.copy_files(root, rel_dir, ext_filter, output_dir, manifest)
    dir = File.join(root, rel_dir)
    return unless File.directory?(dir)

    Dir.glob(File.join(dir, '**', '*')).each do |src|
      next if File.directory?(src)
      next if ext_filter && File.extname(src) != ext_filter

      body          = File.binread(src)
      logical       = '/' + src.sub("#{dir}/", '')
      digest        = Digest::SHA256.hexdigest(body)[0, 16]
      fingerprinted = fingerprint(logical, digest)

      dest = File.join(output_dir, fingerprinted)
      FileUtils.mkdir_p(File.dirname(dest))
      File.binwrite(dest, body)
      if manifest.key?(logical)
        warn "Asset basename collision: #{logical} already mapped, overwriting with #{src}"
      end
      manifest[logical] = fingerprinted
    end
  end

  private_class_method :fingerprint, :copy_files
end
