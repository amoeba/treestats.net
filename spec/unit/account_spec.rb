# spec/unit/account.rb

require_relative '../spec_helper'

describe 'Account', :unit do
  before do
    Account.all.destroy
  end

  it "is valid with a username and password" do
    a = Account.create
    a.name = "test"
    a.password = "test"
    assert a.valid?
  end

  it "is invalid without a username and password" do
    a = Account.create
    assert !a.valid?
  end
end
