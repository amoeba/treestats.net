require_relative '../spec_helper'
require 'securerandom'

describe BulkUploadJob do
  let(:emu_server)    { "TestServer" }
  let(:retail_server) { AppHelper.retail_servers.first }

  before do
    Character.all.destroy
    Allegiance.all.destroy
  end

  # Write records as NDJSON to a temp file and return its path
  def ndjson_file(*records)
    path = "/tmp/bulk_upload_test_#{SecureRandom.uuid}"
    File.write(path, records.map(&:to_json).join("\n"))
    path
  end

  # Write records as a JSON array to a temp file and return its path
  def json_array_file(*records)
    path = "/tmp/bulk_upload_test_#{SecureRandom.uuid}"
    File.write(path, records.to_json)
    path
  end

  def perform_job(file_path, content_type = "application/x-ndjson")
    BulkUploadJob.new.perform(file_path, content_type)
  end

  # ---------------------------------------------------------------------------
  describe "parsing" do
    it "reads NDJSON (one object per line)" do
      path = ndjson_file(
        { "name" => "Stormwall", "server" => emu_server },
        { "name" => "Asheron",   "server" => emu_server }
      )
      perform_job(path)
      assert_equal 2, Character.count
    end

    it "reads a JSON array" do
      path = json_array_file(
        { "name" => "Stormwall", "server" => emu_server },
        { "name" => "Asheron",   "server" => emu_server }
      )
      perform_job(path, "application/json")
      assert_equal 2, Character.count
    end

    it "ignores blank lines in NDJSON" do
      path = "/tmp/bulk_upload_test_#{SecureRandom.uuid}"
      File.write(path, "\n#{{"name" => "Stormwall", "server" => emu_server}.to_json}\n\n")
      perform_job(path)
      assert_equal 1, Character.count
    end
  end

  # ---------------------------------------------------------------------------
  describe "character creation" do
    it "creates a character with the correct name and server" do
      path = ndjson_file({ "name" => "Stormwall", "server" => emu_server })
      perform_job(path)
      c = Character.find_by(name: "Stormwall", server: emu_server)
      refute_nil c
    end

    it "updates an existing character rather than creating a duplicate" do
      Character.create!(name: "Stormwall", server: emu_server, level: 100)
      path = ndjson_file({ "name" => "Stormwall", "server" => emu_server, "level" => 200 })
      perform_job(path)
      assert_equal 1, Character.count
      assert_equal 200, Character.find_by(name: "Stormwall").level
    end

    it "parses the birth date field" do
      path = ndjson_file({ "name" => "OldChar", "server" => emu_server, "birth" => "2/14/2003 12:00:00 AM" })
      perform_job(path)
      c = Character.find_by(name: "OldChar")
      assert_instance_of DateTime, c.birth
    end

    it "creates an allegiance when allegiance_name is present" do
      path = ndjson_file({ "name" => "Knight", "server" => emu_server, "allegiance_name" => "Round Table" })
      perform_job(path)
      assert Allegiance.find_by(server: emu_server, name: "Round Table")
    end

    it "does not create an allegiance when allegiance_name is absent" do
      path = ndjson_file({ "name" => "Loner", "server" => emu_server })
      perform_job(path)
      assert_equal 0, Allegiance.count
    end
  end

  # ---------------------------------------------------------------------------
  describe "filtering" do
    it "skips characters from retail servers" do
      path = ndjson_file(
        { "name" => "Retail Guy", "server" => retail_server },
        { "name" => "Emulator",   "server" => emu_server }
      )
      perform_job(path)
      assert_equal 1, Character.count
      assert Character.find_by(name: "Emulator")
    end

    it "skips records with a malformed patron name (\"??\")" do
      path = ndjson_file(
        { "name" => "Good",   "server" => emu_server },
        { "name" => "Broken", "server" => emu_server, "patron" => { "name" => "??" } }
      )
      perform_job(path)
      assert_equal 1, Character.count
      assert Character.find_by(name: "Good")
    end

    it "removes the verification key field before saving" do
      path = ndjson_file({ "name" => "Foo", "server" => emu_server, "key" => "secret123" })
      perform_job(path)
      c = Character.find_by(name: "Foo")
      refute_nil c
      assert_nil c["key"]
    end
  end

  # ---------------------------------------------------------------------------
  describe "failure behavior" do
    it "raises and fails the job on malformed JSON" do
      path = "/tmp/bulk_upload_test_#{SecureRandom.uuid}"
      File.write(path, "not json at all {{{")
      assert_raises(JSON::ParserError) { perform_job(path, "application/json") }
    end

    it "deletes the temp file after successful processing" do
      path = ndjson_file({ "name" => "Foo", "server" => emu_server })
      perform_job(path)
      refute File.exist?(path)
    end

    it "deletes the temp file even when the job fails" do
      path = "/tmp/bulk_upload_test_#{SecureRandom.uuid}"
      File.write(path, "not json {{{")
      assert_raises(JSON::ParserError) { perform_job(path, "application/json") }
      refute File.exist?(path)
    end
  end
end
