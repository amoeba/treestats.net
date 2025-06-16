require_relative '../spec_helper'
require './helpers/account_helper'

describe AccountHelper do
  describe '.field_value' do
    it 'maps followers correctly' do
      value_proc = AccountHelper.field_value(:allegiance, 'followers')
      assert_equal 99, value_proc.call({ followers: 99 })
    end
  end
end
