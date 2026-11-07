require_relative '../spec_helper'

describe "PlayerCount", :unit do
  it "validates the compact source enum" do
    assert PlayerCount.new(source: "p").valid?
    assert PlayerCount.new(source: "s").valid?
    assert PlayerCount.new.valid?
    assert PlayerCount.new(source: "plugin").valid?
    assert PlayerCount.new(source: "server").valid?
    refute PlayerCount.new(source: "bogus").valid?
  end

  it "stores the enum under the short field while exposing source" do
    document = PlayerCount.new(source: "s")
    assert_equal "s", document.attributes[PlayerCount::SOURCE_FIELD.to_s]
    assert_equal "s", document.source
    assert_equal "server", document.effective_source
  end

  it "maps compact and legacy source codes to friendly names" do
    assert_equal "plugin", PlayerCount.new.effective_source
    assert_equal "plugin", PlayerCount.new(source: "p").effective_source
    assert_equal "plugin", PlayerCount.new(source: "plugin").effective_source
    assert_equal "server", PlayerCount.new(source: "s").effective_source
    assert_equal "server", PlayerCount.new(source: "server").effective_source
    assert_equal "server", PlayerCount.instantiate({"r" => "s"}).effective_source
    assert_equal "server", PlayerCount.instantiate({"source" => "server"}).effective_source
  end
end
