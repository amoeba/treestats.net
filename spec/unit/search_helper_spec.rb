require_relative '../spec_helper'

describe 'SearchHelper', :unit do
  it "still works without a query" do
    result = SearchHelper.process_search()

    assert_equal({}, result)
  end

  it "filters by name for a simple query" do
    result = SearchHelper.process_search("foo")

    assert_equal({:name => /foo/i}, result)
  end

  it "can handle various fields in the query" do
    result = SearchHelper.process_search("level:275")
    assert_equal({:level => 275 }, result)

    result = SearchHelper.process_search("level: 275")
    assert_equal({:name => /275/i }, result)

    result = SearchHelper.process_search("     level:    275    ")
    assert_equal({:name => /275/i }, result)

    result = SearchHelper.process_search("level:12")
    assert_equal({:level => 12 }, result)

    result = SearchHelper.process_search("level:12 rank:2")
    assert_equal({:level => 12, :rank => 2}, result)

    result = SearchHelper.process_search("foo:bar bazz:buzz")
    assert_equal({:foo => /bar/i, :bazz => /buzz/i}, result)
  end

  it "doesn't use unbonded regexp for gender" do
    result = SearchHelper.process_search("gender:male")
    assert_equal({:gender => /\Amale\Z/i }, result)
  end

  it "parses the page param well" do
    assert_equal(SearchHelper.get_page(nil), 1)
    assert_equal(SearchHelper.get_page("3"), 3)
    assert_equal(SearchHelper.get_page("03"), 3)
    assert_equal(SearchHelper.get_page("a"), 1)
    assert_equal(SearchHelper.get_page(-1), 1)
  end
end
