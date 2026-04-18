require 'digest/md5'
require 'json'
require 'sassc'

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
  attr_reader :manifest

  def initialize(root)
    @root = root
    @manifest = {}

    if production?
      load_manifest
    else
      load_assets_into_memory
    end
  end

  def call(env)
    path = env['PATH_INFO'].to_s.split('?').first

    if production?
      serve_from_disk(path)
    else
      serve_from_memory(path)
    end
  end

  def self.precompile(root)
    require 'fileutils'
    output_dir = File.join(root, 'public', 'assets')
    FileUtils.rm_rf(output_dir)
    FileUtils.mkdir_p(output_dir)

    manifest = {}

    compile_scss(root, output_dir, manifest)
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

  def load_assets_into_memory
    @assets = {}
    load_scss_into_memory
    load_files_into_memory('assets/javascripts', '.js')
    load_files_into_memory('assets/images')
  end

  def serve_from_memory(fingerprinted_path)
    asset = @assets[fingerprinted_path]
    return [404, {}, ['Not found']] unless asset

    headers = {
      'Content-Type'  => asset[:content_type],
      'Cache-Control' => 'public, max-age=31536000, immutable',
    }
    [200, headers, [asset[:body]]]
  end

  def load_scss_into_memory
    scss_path = File.join(@root, 'assets', 'stylesheets', 'application.css.scss')
    return unless File.exist?(scss_path)

    css = SassC::Engine.new(File.read(scss_path), style: :compressed, load_paths: [
      File.join(@root, 'assets', 'stylesheets')
    ]).render

    register_in_memory('/application.css', css, '.css')
  end

  def load_files_into_memory(rel_dir, ext_filter = nil)
    dir = File.join(@root, rel_dir)
    return unless File.directory?(dir)

    Dir.glob(File.join(dir, '**', '*')).each do |path|
      next if File.directory?(path)
      next if ext_filter && File.extname(path) != ext_filter

      body    = File.binread(path)
      logical = '/' + path.sub("#{dir}/", '')
      register_in_memory(logical, body, File.extname(path))
    end
  end

  def register_in_memory(logical_path, body, ext)
    digest       = Digest::MD5.hexdigest(body)
    fingerprinted = AssetServer.fingerprint(logical_path, digest)
    content_type  = CONTENT_TYPES.fetch(ext, 'application/octet-stream')
    @assets[fingerprinted] = { body: body, content_type: content_type }
    @manifest[logical_path] = fingerprinted
  end

  def self.compile_scss(root, output_dir, manifest)
    scss_path = File.join(root, 'assets', 'stylesheets', 'application.css.scss')
    return unless File.exist?(scss_path)

    css    = SassC::Engine.new(File.read(scss_path), style: :compressed, load_paths: [
      File.join(root, 'assets', 'stylesheets')
    ]).render
    digest       = Digest::MD5.hexdigest(css)
    fingerprinted = fingerprint('/application.css', digest)

    File.write(File.join(output_dir, fingerprinted), css)
    manifest['/application.css'] = fingerprinted
  end

  def self.copy_files(root, rel_dir, ext_filter, output_dir, manifest)
    dir = File.join(root, rel_dir)
    return unless File.directory?(dir)

    Dir.glob(File.join(dir, '**', '*')).each do |src|
      next if File.directory?(src)
      next if ext_filter && File.extname(src) != ext_filter

      body         = File.binread(src)
      logical      = '/' + src.sub("#{dir}/", '')
      digest       = Digest::MD5.hexdigest(body)
      fingerprinted = fingerprint(logical, digest)

      dest = File.join(output_dir, fingerprinted)
      FileUtils.mkdir_p(File.dirname(dest))
      File.binwrite(dest, body)
      manifest[logical] = fingerprinted
    end
  end
end
