require_relative '../spec_helper'
require "./helpers/experience_helper"

describe ExperienceHelper do
  describe ".xp_for_next_level" do
    describe "below max level" do
      let(:character) do
        {
          'level' => 1,
          'total_xp' => 0
        }
      end
      it "builds display string of experience to next level" do
        assert_equal("1,000", ExperienceHelper.xp_for_next_level(character))
      end
    end

    describe "at max level" do
      let(:character) do
        {
          'level' => 275,
          'total_xp' => 191226310247
        }
      end

      it "returns infinity" do
        assert_equal("Infinity", ExperienceHelper.xp_for_next_level(character))
      end
    end

  end

  describe ".level_percent" do
    describe "below max level" do
      let(:character) do
        {
          'level' => 1,
          'total_xp' => 500
        }
      end

      it "calculates the level percent (0.0 - 1.0)" do
        assert_equal(0.5, ExperienceHelper.level_percent(character))
      end
    end

    describe "at max level" do
      let(:character) do
        {
          'level' => 275,
          'total_xp' => 191226310247
        }
      end

      it "returns 0.0" do
        assert_equal(0.0, ExperienceHelper.level_percent(character))
      end
    end
  end

  it "builds string (0%-100%) for percent (0.0 - 1.0)" do
    assert_equal("50%", ExperienceHelper.percent_string(0.5))
  end
end
