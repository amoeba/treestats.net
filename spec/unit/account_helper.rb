# spec/unit/account.rb

require_relative '../spec_helper'

describe 'Character', :unit do
  before do
    Account.all.destroy
  end

  it "is valid with a username and password" do
    a = Account.create
    a.name = "test"
    a.password = "test"
    a.valid?.must_equal false
  end

  it "is invalid without a username and password" do
    a = Account.create
    a.valid?.must_equal false
  end
end
