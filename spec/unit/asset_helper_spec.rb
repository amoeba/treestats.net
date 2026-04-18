require_relative '../spec_helper'
require './helpers/asset_helper'

describe Sinatra::TreeStats::AssetHelper do
  include Sinatra::TreeStats::AssetHelper

  def settings
    asset_server = Struct.new(:manifest).new(@manifest || {})
    Struct.new(:asset_server).new(asset_server)
  end

  it 'stylesheet_path appends .css and returns fingerprinted path on manifest hit' do
    @manifest = { '/application.css' => '/application-abc123.css' }
    assert_equal '/assets/application-abc123.css', stylesheet_path('application')
  end

  it 'stylesheet_path falls back to unfingerprinted path on manifest miss' do
    @manifest = {}
    assert_equal '/assets/application.css', stylesheet_path('application')
  end

  it 'javascript_path appends .js and returns fingerprinted path on manifest hit' do
    @manifest = { '/app.js' => '/app-def456.js' }
    assert_equal '/assets/app-def456.js', javascript_path('app')
  end

  it 'javascript_path falls back to unfingerprinted path on manifest miss' do
    @manifest = {}
    assert_equal '/assets/app.js', javascript_path('app')
  end

  it 'image_path returns fingerprinted path on manifest hit' do
    @manifest = { '/logo.png' => '/logo-ghi789.png' }
    assert_equal '/assets/logo-ghi789.png', image_path('logo.png')
  end

  it 'image_path falls back to unfingerprinted path on manifest miss' do
    @manifest = {}
    assert_equal '/assets/bg_top.jpg', image_path('bg_top.jpg')
  end

  it 'rejects names containing ..' do
    @manifest = {}
    assert_raises(ArgumentError) { image_path('../etc/passwd') }
  end

  it 'rejects names containing single dot component' do
    @manifest = {}
    assert_raises(ArgumentError) { image_path('./foo.png') }
  end
end
