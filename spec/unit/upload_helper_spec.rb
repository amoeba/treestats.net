require_relative '../spec_helper'
require "./helpers/upload_helper"

describe UploadHelper do
  it "always returns valid when no env var is set" do
    without_env("TREESTATS_SECRET") do
      assert UploadHelper.validate("foo")
    end
  end

  it "prints an informative message when eval fails" do
    with_env("TREESTATS_SECRET" => "foo(") do
      assert_output /eval failed/i do
        UploadHelper.validate("whatever")
      end
    end
  end

  it "prints an informative message when call fails" do
    with_env("TREESTATS_SECRET" => "y") do
      assert_output /call failed/i do
        UploadHelper.validate("whatever")
      end
    end
  end

  it "returns false when a message fails validation" do
    with_env("TREESTATS_SECRET" => "x == \"apple\"") do
      assert !UploadHelper.validate("orange")
    end
  end

  it "returns true when a message succeeds validation" do
    with_env("TREESTATS_SECRET" => "x == \"apple\"") do
      assert UploadHelper.validate("apple")
    end
  end

  it "fails on an empty or too-short message" do
    assert UploadHelper.validate(nil) == false
    assert UploadHelper.validate("") == false
  end
end
