require_relative '../spec_helper'
require "./helpers/upload_payload"

describe UploadPayload do
  def sanitize(hash)
    UploadPayload.sanitize(hash)
  end

  it "requires string server and name" do
    assert_raises(UploadPayload::Invalid) { sanitize("server" => {"$ne" => nil}, "name" => "x") }
    assert_raises(UploadPayload::Invalid) { sanitize("server" => "s", "name" => {"$ne" => nil}) }
    assert_raises(UploadPayload::Invalid) { sanitize("server" => "s") }
    assert_raises(UploadPayload::Invalid) { sanitize("name" => "x") }
    assert_raises(UploadPayload::Invalid) { sanitize("server" => "", "name" => "x") }
  end

  it "allows an empty name so the level-1 message still works" do
    result = sanitize("server" => "s", "name" => "")

    assert_equal "", result.payload["name"]
  end

  it "ignores unknown keys and reports them" do
    result = sanitize(
      "server" => "s",
      "name" => "n",
      "_id" => "0" * 24,
      "ip_address" => "1.2.3.4",
      "plugin_version" => "3"
    )

    assert_equal %w[_id ip_address plugin_version], result.ignored
    refute result.payload.key?("_id")
    refute result.payload.key?("ip_address")
    refute result.payload.key?("plugin_version")
  end

  it "coerces numeric scalars and integer strings" do
    result = sanitize("server" => "s", "name" => "n", "race" => 1, "level" => "50")

    assert_equal "1", result.payload["race"]
    assert_equal 50, result.payload["level"]
  end

  it "rejects wrong types on known fields" do
    assert_raises(UploadPayload::Invalid) { sanitize("server" => "s", "name" => "n", "level" => "max") }
    assert_raises(UploadPayload::Invalid) { sanitize("server" => "s", "name" => "n", "race" => {}) }
    assert_raises(UploadPayload::Invalid) { sanitize("server" => "s", "name" => "n", "patron" => "Bob") }
    assert_raises(UploadPayload::Invalid) { sanitize("server" => "s", "name" => "n", "vassals" => "nope") }
    assert_raises(UploadPayload::Invalid) { sanitize("server" => "s", "name" => "n", "titles" => "nope") }
  end

  it "rejects non-string names inside patron and monarch" do
    assert_raises(UploadPayload::Invalid) do
      sanitize("server" => "s", "name" => "n", "patron" => {"name" => {"$ne" => nil}})
    end
    assert_raises(UploadPayload::Invalid) do
      sanitize("server" => "s", "name" => "n", "monarch" => {"name" => 5})
    end
  end

  it "validates the population range" do
    assert_equal 5, sanitize("server" => "s", "name" => "n", "server_population" => 5).population
    assert_equal 0, sanitize("server" => "s", "name" => "n", "server_population" => 0).population
    assert_raises(UploadPayload::Invalid) { sanitize("server" => "s", "name" => "n", "server_population" => -1) }
    assert_raises(UploadPayload::Invalid) { sanitize("server" => "s", "name" => "n", "server_population" => "abc") }
    assert_raises(UploadPayload::Invalid) { sanitize("server" => "s", "name" => "n", "server_population" => 100_001) }
  end

  it "drops malformed vassal entries" do
    result = sanitize(
      "server" => "s",
      "name" => "n",
      "vassals" => ["x", {}, {"name" => "v"}, {"name" => {"$ne" => nil}}]
    )

    assert_equal [{}, {"name" => "v"}], result.payload["vassals"]
  end

  it "keeps null known fields as nil" do
    result = sanitize("server" => "s", "name" => "n", "patron" => nil, "level" => nil)

    assert_nil result.payload["patron"]
    assert_nil result.payload["level"]
  end

  it "sanitizes ignored keys for the response header" do
    header = UploadPayload.ignored_header(["ok_key", "bad key", "newline\nkey"])

    assert_equal "ok_key,bad?key,newline?key", header
  end
end
