# spec/stories/app_spec.rb

require_relative '../story_helper.rb'

describe "AppStory" do
  before do
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
