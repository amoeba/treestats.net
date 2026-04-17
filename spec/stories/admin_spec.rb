require_relative '../story_helper.rb'
require 'base64'

describe "AdminLogsStory" do
  def get_logs(user: "admin", password: "secret", accept: "application/json")
    credentials = Base64.strict_encode64("#{user}:#{password}")
    get("/admin/logs", {}, {
      "HTTP_ACCEPT"        => accept,
      "HTTP_AUTHORIZATION" => "Basic #{credentials}"
    })
  end

  before do
    BulkUploadLog.all.destroy
  end

  describe "authentication" do
    it "returns 401 without credentials" do
      with_env("SIDEKIQ_WEB_PASSWORD" => "secret") do
        get "/admin/logs"
        assert_equal 401, last_response.status
      end
    end

    it "returns 401 with wrong credentials" do
      with_env("SIDEKIQ_WEB_PASSWORD" => "secret") do
        get_logs(password: "wrongpassword")
        assert_equal 401, last_response.status
      end
    end

    it "returns 401 response as JSON" do
      with_env("SIDEKIQ_WEB_PASSWORD" => "secret") do
        get "/admin/logs"
        body = JSON.parse(last_response.body)
        assert_equal "unauthorized", body["error"]
      end
    end

    it "returns 200 with correct credentials" do
      with_env("SIDEKIQ_WEB_PASSWORD" => "secret") do
        get_logs
        assert_equal 200, last_response.status
      end
    end

    it "returns a JSON array with correct credentials" do
      with_env("SIDEKIQ_WEB_PASSWORD" => "secret") do
        get_logs
        body = JSON.parse(last_response.body)
        assert_instance_of Array, body
      end
    end
  end
end
