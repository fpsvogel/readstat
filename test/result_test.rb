# frozen_string_literal: true

require_relative "test_helper"
require_relative "test_base_with_items"

require "open3"
require "library/library"
require "result"

class ResultTest < ReadstatTestWithItems
  @config = Readstat.config
  Readstat::CLI.load(@config.fetch(:item), @config.fetch(:output))
  @err_block = lambda do |err|
    @err_log << err
    #err.show
  end
  Colors = Readstat::Colors

  def setup
    self.class.clear_err_log
  end

  def command_output(input, items = basic_items.values)
    output = with_captured_stdout(print_also: true) do
      Readstat::Command.parse(input, config.fetch(:item))
                       .result(Readstat::Library.new(items, config.fetch(:item)))
                       .output(config.fetch(:output))
    end
    Readstat::Colors.strip(output)
  rescue Readstat::AppError => e; err_block.call(e)
  end

  def test_depth_1
    skip
    test_item = all_items[:podcast]
    actual = command_output("average length", [test_item])
    expected = test_item.length
    assert_equal actual, actual # expected.to_s + "\n", actual
  end

  def test_depth_2_table
    skip
    test_items = items(:prequel, :podcast, :docu)
    actual = command_output("average length monthly view=table", test_items)
    expected = <<'EOM'.freeze
# TODO
EOM
    assert_equal actual, actual
  end

  def test_depth_2_bar
    skip
    test_items = items(:prequel, :podcast, :docu)
    actual = command_output("average length monthly view=bar", test_items)
    expected = <<'EOM'.freeze
# TODO
EOM
    assert_equal actual, actual
  end

  def test_depth_2_pie
    skip
    test_items = items(:prequel, :podcast, :docu, :novel)
    actual = command_output("average length monthly view=pie", test_items)
    expected = <<'EOM'.freeze
        ▅▅▅▅▅
    ▅▅▅▅▅▅▅▅▅▅▅▅▅
  ▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅
 ▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅     ▅ 2020-10 34.32%
▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅
▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅    ▅ 2021-01 24.49%
▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅
 ▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅     ▅ 2021-02 41.19%
  ▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅
    ▅▅▅▅▅▅▅▅▅▅▅▅▅
        ▅▅▅▅▅
EOM
    assert_equal actual, actual
  end

  def test_depth_3_table
    skip
    test_items = items(:prequel, :podcast, :docu)
    actual = command_output("average length monthly by genre view=table", test_items)
    expected = nil
    assert_equal actual, actual
  end

  def test_depth_3_bar
    skip
    test_items = items(:prequel, :podcast, :docu)
    actual = command_output("average length monthly by genre view=bar", test_items)
    expected = nil
    assert_equal actual, actual
  end

  def test_depth_3_pie
    skip
    test_items = items(:prequel, :podcast, :docu)
    actual = command_output("average length monthly by genre view=pie", test_items)
    expected = nil
    assert_equal actual, actual
  end

  def test_depth_4_table
    skip
    test_items = items(:prequel, :booklet, :podcast, :docu)
    actual = command_output("count length monthly by genre view=table", test_items)
    expected = nil
    assert_equal actual, actual
  end

  def test_depth_4_bar
    skip
    test_items = items(:prequel, :booklet, :podcast, :docu)
    actual = command_output("count length monthly by genre view=bar", test_items)
    expected = nil
    assert_equal actual, actual
  end

  def test_depth_4_pie
    skip
    test_items = items(:prequel, :booklet, :podcast, :docu)
    actual = command_output("count length monthly by genre view=pie", test_items)
    expected = nil
    assert_equal actual, actual
  end

  def test_depth_5
    skip
    test_items = items(:prequel, :booklet, :podcast, :docu)
    actual = command_output("list by rating monthly by genre", test_items)
    expected = nil
    assert_equal actual, actual
  end

  def test_list
    skip
    test_items = items(:prequel, :booklet, :podcast, :docu)
    actual = command_output("list by rating", test_items)
    expected = nil
    assert_equal actual, actual
  end

  def test_list_numeric_view_not_allowed
    skip
    test_items = items(:prequel, :booklet, :podcast, :docu)
    actual = command_output("list by rating view=bar", test_items)
    expected = nil
    assert_equal actual, actual
  end

  def test_hours_unit
    skip
    test_items = items(:prequel, :booklet, :podcast, :docu)
    actual = command_output("top lengths unit=hours view=bar", test_items)
    expected = nil
    assert_equal actual, actual
  end

  def test_pages_unit
    skip
    test_items = items(:prequel, :booklet, :podcast, :docu)
    actual = command_output("top lengths unit=pages view=bar", test_items)
    expected = nil
    assert_equal actual, actual
  end

  def test_pages_unit_alt_singular
    skip
    test_items = items(:prequel, :booklet, :podcast, :docu)
    actual = command_output("top lengths unit=page view=bar", test_items)
    expected = nil
    assert_equal actual, actual
  end
end
