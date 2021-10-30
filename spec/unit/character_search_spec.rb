require_relative '../spec_helper'
require "./lib/character_search"

describe CharacterSearch do

  subject { CharacterSearch.new(input) }

  let(:input) { 'Asheron' }

  describe "parsing filters" do

    before do
      @results = subject.filters
    end

    describe "only name" do
      it 'returns name filter' do
        assert_equal(['name:Asheron'], @results)
      end
    end

    describe "only filter" do
      let(:input) { 'level:126' }

      it 'returns name filter' do
        assert_equal(['level:126'], @results)
      end
    end

    describe "name and filter" do
      let(:input) { 'Asheron level:126' }

      it 'returns both' do
        assert_equal(['name:Asheron', 'level:126'], @results)
      end
    end

    describe "incomplete filter" do
      let(:input) { 'level:' }

      it "discards" do
        assert_equal([], @results)
      end

    end

    describe "unknown field" do
      let(:input) { 'unknown:123' }

      it "discards" do
        assert_equal([], @results)
      end
    end

    describe "to_h" do
      let(:input) { 'Asheron level:126' }

      before do
        @results = subject.to_h
      end

      it do
        assert_equal({
            name: 'Asheron',
            level: '126'
          },
          @results
        )
      end
    end

  end

end