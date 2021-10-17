require_relative '../spec_helper'
require './helpers/date_helper'

describe DateHelper do
  describe '.ensure_century' do
    before do
      date = Date.strptime(date_string, '%m/%d/%Y')
      @result = DateHelper.ensure_century(date)
    end

    describe 'when date string contains century' do
      let(:date_string) { '10/07/2021' }

      it 'returns date with correct century' do
        assert_equal(2021, @result.year)
      end
    end

    describe 'when date string does NOT contain century' do
      let(:date_string) { '10/07/21' }

      it 'returns date with correct century' do
        assert_equal(2021, @result.year)
      end
    end
  end
end
