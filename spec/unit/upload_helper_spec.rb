require_relative '../spec_helper'
require './helpers/upload_helper'
require 'openssl'

describe UploadHelper do
  it 'always returns valid when no env var is set' do
    without_env('TREESTATS_SECRET') do
      assert UploadHelper.validate('foo', 'whatever')
    end
  end

  it 'returns false when signature does not match' do
    with_env('TREESTATS_SECRET' => 'secret') do
      wrong_sig = OpenSSL::HMAC.hexdigest('SHA256', 'secret', 'other')
      assert !UploadHelper.validate('body', wrong_sig)
    end
  end

  it 'returns true when signature matches' do
    with_env('TREESTATS_SECRET' => 'secret') do
      sig = OpenSSL::HMAC.hexdigest('SHA256', 'secret', 'body')
      assert UploadHelper.validate('body', sig)
    end
  end

  it 'fails when signature is missing' do
    with_env('TREESTATS_SECRET' => 'secret') do
      assert !UploadHelper.validate('body', nil)
    end
  end

  it 'fails on an empty or too-short message' do
    assert UploadHelper.validate(nil, 'sig') == false
    assert UploadHelper.validate('', 'sig') == false
  end
end
