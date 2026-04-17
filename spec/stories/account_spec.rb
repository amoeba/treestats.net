# spec/stories/app_spec.rb

require_relative '../story_helper.rb'

describe "AppStory" do
  before do
    ApiKey.all.destroy
    Account.all.destroy
  end

  it "successfully creates an account" do
    post('/account/create/', '{
      "name" : "Account Test",
      "password" : "passw0rd"}')

    assert_equal last_response.body, "Account successfully created."
  end

  it "a duplicate account won't be created" do
    post('/account/create', '{
      "name" : "Account Test",
      "password" : "passw0rd"}')

    post('/account/create', '{
      "name" : "Account Test",
      "password" : "passw0rd"}')

    assert_equal last_response.body, "Account with this name already exists."
  end

  it "successfully logs in" do
    post('/account/create', '{
      "name" : "Account Test",
      "password" : "passw0rd"}')

    post('/account/login', '{
      "name" : "Account Test",
      "password" : "passw0rd"}')

    assert_equal last_response.body, "You are now logged in."
  end

  it "fails to log in if we supply the wrong credentials" do
    post('/account/create', '{
      "name" : "Account Test",
      "password" : "passw0rd"}')

    post('/account/login', '{
      "name" : "Account Test",
      "password" : "passw0rdd"}')

    assert_equal last_response.body, "Login failed. Name/password not found."
  end

end

describe "ApiKeyStory" do
  before do
    ApiKey.all.destroy
    Account.all.destroy
    post('/account/create', '{"name":"TestUser","password":"passw0rd"}')
  end

  def request_key(name: "TestUser", password: "passw0rd")
    post('/account/key',
         JSON.generate({ "name" => name, "password" => password }),
         { "CONTENT_TYPE" => "application/json" })
  end

  # ---------------------------------------------------------------------------
  describe "happy path" do
    it "returns 200" do
      request_key
      assert_equal 200, last_response.status
    end

    it "returns application/json" do
      request_key
      assert last_response.headers["Content-Type"].include?("application/json")
    end

    it "returns a key" do
      request_key
      body = JSON.parse(last_response.body)
      refute_nil body["key"]
    end

    it "key starts with ts_" do
      request_key
      key = JSON.parse(last_response.body)["key"]
      assert key.start_with?("ts_")
    end

    it "calling twice returns the same key" do
      request_key
      first  = JSON.parse(last_response.body)["key"]
      request_key
      second = JSON.parse(last_response.body)["key"]
      assert_equal first, second
    end
  end

  # ---------------------------------------------------------------------------
  describe "bad request body" do
    it "returns 400 for a non-JSON body" do
      post('/account/key', "not json", { "CONTENT_TYPE" => "application/json" })
      assert_equal 400, last_response.status
      body = JSON.parse(last_response.body)
      assert_equal "invalid JSON", body["error"]
    end

    it "returns 400 when name is missing" do
      post('/account/key',
           JSON.generate({ "password" => "passw0rd" }),
           { "CONTENT_TYPE" => "application/json" })
      assert_equal 400, last_response.status
      assert_equal "name and password are required", JSON.parse(last_response.body)["error"]
    end

    it "returns 400 when password is missing" do
      post('/account/key',
           JSON.generate({ "name" => "TestUser" }),
           { "CONTENT_TYPE" => "application/json" })
      assert_equal 400, last_response.status
      assert_equal "name and password are required", JSON.parse(last_response.body)["error"]
    end

    it "returns 400 when name is explicitly null" do
      post('/account/key',
           JSON.generate({ "name" => nil, "password" => "passw0rd" }),
           { "CONTENT_TYPE" => "application/json" })
      assert_equal 400, last_response.status
      assert_equal "name and password are required", JSON.parse(last_response.body)["error"]
    end

    it "returns 400 when password is explicitly null" do
      post('/account/key',
           JSON.generate({ "name" => "TestUser", "password" => nil }),
           { "CONTENT_TYPE" => "application/json" })
      assert_equal 400, last_response.status
      assert_equal "name and password are required", JSON.parse(last_response.body)["error"]
    end
  end

  # ---------------------------------------------------------------------------
  describe "account not found" do
    it "returns 401 for a wrong password" do
      request_key(password: "wrongpassword")
      assert_equal 401, last_response.status
    end

    it "returns 401 for a non-existent account name" do
      request_key(name: "NoSuchUser")
      assert_equal 401, last_response.status
    end

    it "returns a JSON error body" do
      request_key(password: "wrongpassword")
      body = JSON.parse(last_response.body)
      assert_equal "invalid credentials", body["error"]
    end
  end
end
