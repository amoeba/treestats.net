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

  it "ignores unknown keys" do
    result = sanitize(
      "server" => "s",
      "name" => "n",
      "_id" => "0" * 24,
      "ip_address" => "1.2.3.4",
      "plugin_version" => "3"
    )

    assert_equal({"server" => "s", "name" => "n"}, result.payload)
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

  it "treats the population as best effort" do
    assert_equal 5, sanitize("server" => "s", "name" => "n", "server_population" => 5).population
    assert_equal 1_000_000, sanitize("server" => "s", "name" => "n", "server_population" => 1_000_000).population
    assert_nil sanitize("server" => "s", "name" => "n", "server_population" => 0).population
    assert_nil sanitize("server" => "s", "name" => "n", "server_population" => -1).population
    assert_nil sanitize("server" => "s", "name" => "n", "server_population" => "abc").population
    assert_nil sanitize("server" => "s", "name" => "n", "server_population" => 1.5).population
    assert_nil sanitize("server" => "s", "name" => "n", "server_population" => nil).population
  end

  it "drops malformed vassal entries" do
    result = sanitize(
      "server" => "s",
      "name" => "n",
      "vassals" => ["x", {}, {"name" => "v"}, {"name" => {"$ne" => nil}}]
    )

    assert_equal [{}, {"name" => "v"}], result.payload["vassals"]
  end

  it "allows account names on plugin payloads by default" do
    result = sanitize("server" => "s", "name" => "n", "account_name" => "plugin-account")

    assert_equal "plugin-account", result.payload["account_name"]
  end

  it "rejects account fields by presence on direct payloads" do
    %w[account_name acc].each do |key|
      ["account", "", nil, 123, {}].each do |value|
        error = assert_raises(UploadPayload::Invalid) do
          UploadPayload.sanitize({"server" => "s", "name" => "n", key => value}, allow_account_name: false)
        end

        assert_equal key, error.field
        assert_includes error.to_s, "only allowed for plugin uploads"
      end
    end
  end

  it "rejects account fields on related characters in direct payloads" do
    [
      {"monarch" => {"name" => "m", "account_name" => "account"}},
      {"patron" => {"name" => "p", "acc" => nil}},
      {"vassals" => [{"name" => "v", "account_name" => ""}]},
      {"monarch" => {"name" => "m", "vassals" => [{"name" => "v", "acc" => "account"}]}}
    ].each do |related|
      assert_raises(UploadPayload::Invalid) do
        UploadPayload.sanitize({"server" => "s", "name" => "n"}.merge(related), allow_account_name: false)
      end
    end
  end

  it "keeps null known fields as nil" do
    result = sanitize("server" => "s", "name" => "n", "patron" => nil, "level" => nil)

    assert_nil result.payload["patron"]
    assert_nil result.payload["level"]
  end
end
