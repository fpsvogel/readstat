# frozen_string_literal: true

require_relative "test_helper"
require_relative "test_base"

require "library/load_items"
require "library/library"
require "item/item"

class LoadItemsTest < ReadstatTest
  @config = Readstat.config
  @err_block = lambda do |err|
    @err_log << err
    err.show
  end

  module Files
    ## VALID INPUT
    TYPICAL = <<~EOM.freeze
      Rating|Name|ISBN-10/ASIN,Sources|Dates Added;Started|Dates Finished|Genre|Length|Notes
      \\------ CURRENTLY READING
       |🔊The Jedi Doth Return [William Shakespeare's Star Wars, #6]|159474713X, http://iandoescher.com/ - author|2020-11-05| |drama, poetry|3:33
      \\-- SOON
      \\Ruby on Rails Tutorial
      \\------ DONE READING
      5|⚡Sandi Metz - Practical Object-Oriented Design: An Agile Primer Using Ruby|B07F88LY9M https://lexpublib.overdrive.com/media/4166664|2020-09-10,2020-11-1|2020-09-20,2020-11-15|rubyrails|286|A revelation. Must re-read soon.
      4|📕Paradise Lost|B0042JSMDW, Little Library|#2019-08-15;2020-09-01|2020-10-25|poetry|453
    EOM
    OMIT_HEADINGS = <<~EOM.freeze
       |🔊The Jedi Doth Return [William Shakespeare's Star Wars, #6]|159474713X, http://iandoescher.com/ - author|2020-11-05| |drama, poetry|3:33
      5|⚡Sandi Metz - Practical Object-Oriented Design: An Agile Primer Using Ruby|B07F88LY9M https://lexpublib.overdrive.com/media/4166664|2020-09-10,2020-11-1|2020-09-20,2020-11-15|rubyrails|286|A revelation. Must re-read soon.
      4|📕Paradise Lost|B0042JSMDW, Little Library|#2019-08-15;2020-09-01|2020-10-25|poetry|453
    EOM
    GROUPED_ITEMS = <<~EOM.freeze
      2|DNF podcasts 🔊FiveThirtyEight Politics 🔊The NPR Politics Podcast 🔊Pod Save America| |2020-08-24|2020-08-24|politics|0:30|Not very deep. Disappointing.
    EOM
    DNF_PERCENT = <<~EOM.freeze
      2|DNF 50% 🔊FiveThirtyEight Politics| |2020-08-24|2020-08-24|politics|0:30|Not very deep. Disappointing.
    EOM
    DNF_PERCENT_WITH_REREADS = <<~EOM.freeze
      2|DNF 50% 🔊FiveThirtyEight Politics| |2020-08-24,2020-12-01|2020-08-24,2020-12-01|politics|0:30|Not very deep. Disappointing.
    EOM
    DNF_PERCENTS_IN_DATES = <<~EOM.freeze
      2|🔊FiveThirtyEight Politics| |2020-08-24,2020-12-01|DNF 50% 2020-08-24,DNF 2020-12-01|politics|0:30|Not very deep. Disappointing.
    EOM
    DATES_REVERSE_ORDER = <<~EOM.freeze
      5|⚡Sandi Metz - Practical Object-Oriented Design: An Agile Primer Using Ruby|B07F88LY9M https://lexpublib.overdrive.com/media/4166664|2020-11-1,2020-09-10|2020-11-15,2020-09-20|rubyrails|286|A revelation. Must re-read soon.
    EOM
    OMIT_SOME_DATES_STARTED = <<~EOM.freeze
      2|DNF 🔊Pod Save America| |2020-08-24|2020-08-24,2021-01-01,2021-02-01|politics|0:30|Not very deep. Disappointing.
    EOM
    OMIT_ALL_DATES_STARTED = <<~EOM.freeze
      2|DNF 🔊The NPR Politics Podcast| | |2020-08-24,2021-01-01|politics|0:30|Not very deep. Disappointing.
    EOM
    SOURCES = <<~EOM.freeze
       |some title|159474713X, Lex Pub, http://iandoescher.com/ - the author, Libby app|||drama|300
       |some title|the author - http://iandoescher.com/ 159474713X|||drama|300
       |some title|Libby app 159474713X Lex Pub|||drama|300
       |some title|Hoopla 159474713X Lex Pub http://iandoescher.com/ Libby app|||drama|300
    EOM
    SPACES_AND_TABS = <<~EOM.freeze
      4  |		Paradise Lost  |  B0042JSMDW ,		Little Library  |  #2019-08-15  ;  2020-09-01  |  2020-10-25  |  poetry  |  453
    EOM
    NO_ITEMS = <<~EOM.freeze

    EOM
    ## INVALID INPUT
    TWO_ISBNS = <<~EOM.freeze
        |some title|159474713X, Lex Pub, B0042JSMDW|||drama|300
    EOM
    # a Rating column is missing
    MISSING_COLUMN = <<~EOM.freeze
      Paradise Lost|B0042JSMDW, Little Library|#2019-08-15;2020-09-01|2020-10-25|poetry|453
      2|DNF 🔊Pod Save America| |2020-08-24|2020-08-24|politics|0:30|Not very deep. Disappointing.
    EOM
    # any column can be blank except Name, Genre, and Length
    BLANK_COLUMN_ERROR = <<~EOM.freeze
      ||||| |
    EOM
    # the Title part of the Name column must not be blank
    BLANK_TITLE_ERROR = <<~EOM.freeze
      |🔊 🔊some title|||||300
    EOM
    BLANK_COLUMN_WARNING = <<~EOM.freeze
      |some title||2021-01-01|2021-01-01||300
    EOM
    BLANK_COLUMN_NO_WARNING_FOR_CURRENT_OR_WILL = <<~EOM.freeze
      |some title||2021-01-01|||300
      |some title|||||300
    EOM
    # error only if nonsense Rating, Dates, or Length
    VALID_NONSENSE = <<~EOM.freeze
      |🤪123 - .||||456|9999999999
    EOM
    INVALID_RATING = <<~EOM.freeze
      A|some title|||||300
    EOM
    # Dates must be parsable
    INVALID_DATES_PARSE = <<~EOM.freeze
      |some title||2020-05-27|2020-052-29||300
    EOM
    # Dates must make logical sense. Here there is more than one additional
    # start date than end dates. every start date must have an end date except
    # for the last (meaning it's in progress and not yet finished).
    INVALID_DATES_COUNT = <<~EOM.freeze
      |some title||2020-05-27,2020-06-01,2020-07-01|2020-05-29||300
    EOM
    # Dates are not in the right order
    INVALID_DATES_ORDER = <<~EOM.freeze
      |some title||2020-05-29|2020-05-27||300
    EOM
    # Length must be an integer (for pages) or h:mm (hours and minutes)
    INVALID_LENGTH = <<~EOM.freeze
      |some title|||||2 hours
    EOM
  end

  @all_items =
    {
      jedi: Readstat::Item.create(
        { format: :audio,
          title: "The Jedi Doth Return [William Shakespeare's Star Wars, #6]",
          isbn: "159474713X",
          sources: [["author", "http://iandoescher.com"]],
          perusals: [{ date_started: "2020-11-05" }],
          genres: %w[drama poetry],
          length: "3:33" },
        config.fetch(:item)
      ),
      metz: Readstat::Item.create(
        { rating: 5,
          format: :ebook,
          author: "Sandi Metz",
          title: "Practical Object-Oriented Design: An Agile Primer Using Ruby",
          isbn: "B07F88LY9M",
          sources: [["Lexington Public Library", "https://lexpublib.overdrive.com/media/4166664"]],
          perusals: [{ date_started:  "2020-09-10",
                       date_finished: "2020-09-20" }],
          genres: ["rubyrails"],
          length: 286,
          notes: "A revelation. Must re-read soon." },
        config.fetch(:item)
      ),
      milton: Readstat::Item.create(
        { rating: 4,
          format: :print,
          author: nil,
          title: "Paradise Lost",
          isbn: "B0042JSMDW",
          sources: [["Little Library"]],
          perusals: [{ date_added:    "2019-08-15",
                       date_started:  "2020-09-01",
                       date_finished: "2020-10-25" }],
          genres: ["poetry"],
          length: 453,
          notes: nil },
        config.fetch(:item)
      ),
      pod1: Readstat::Item.create(
        { rating: 2,
          format: :audio,
          title: "FiveThirtyEight Politics",
          perusals: [{ date_started:  "2020-08-24",
                       date_finished: "2020-08-24",
                       progress:      0 }],
          genres: ["politics"],
          length: "0:30",
          notes: "Not very deep. Disappointing." },
        config.fetch(:item)
      ),
      blank: Readstat::Item.create(
        { title: "some title",
          perusals: [{ date_started:  "2021-01-01",
                       date_finished: "2021-01-01",
                       progress:      100 }],
          length: 300 },
        config.fetch(:item)
      ),
      blank_current: Readstat::Item.create(
        { title: "some title",
          perusals: [{ date_started:  "2021-01-01",
                       date_finished: nil,
                       progress:      0 }],
          length: 300 },
        config.fetch(:item)
      ),
      blank_will: Readstat::Item.create(
        { title: "some title",
          perusals: [{ date_started:  nil,
                       date_finished: nil,
                       progress:      0 }],
          length: 300 },
        config.fetch(:item)
      ),
      nonsense: Readstat::Item.create(
        { author: "🤪123",
          title: ".",
          genres: ["456"],
          length: 9999999999 },
        config.fetch(:item)
      ),
      sources_1: Readstat::Item.create(
        { title: "some title",
          isbn: "159474713X",
          sources: [["Lex Pub"],
                    ["the author", "http://iandoescher.com"],
                    ["Libby app"]],
          genres: %w[drama],
          length: 300 },
        config.fetch(:item)
      ),
      sources_2: Readstat::Item.create(
        { title: "some title",
          isbn: "159474713X",
          sources: [["the author", "http://iandoescher.com"]],
          genres: %w[drama],
          length: 300 },
        config.fetch(:item)
      ),
      sources_3: Readstat::Item.create(
        { title: "some title",
          isbn: "159474713X",
          sources: [["Libby app"],
                    ["Lex Pub"]],
          genres: %w[drama],
          length: 300 },
        config.fetch(:item)
      ),
      sources_4: Readstat::Item.create(
        { title: "some title",
          isbn: "159474713X",
          sources: [["Hoopla"],
                    ["Lex Pub"],
                    ["http://iandoescher.com"],
                    ["Libby app"]],
          genres: %w[drama],
          length: 300 },
        config.fetch(:item)
      )
    }
  @all_items[:metz_reread] = @all_items[:metz].with_dates("2020-11-01", "2020-11-15")
  @all_items[:pod2] = Readstat::Item.create(
    all_items[:pod1].data.merge(
      { title: "The NPR Politics Podcast" }), config.fetch(:item))
  @all_items[:pod3] = Readstat::Item.create(
    all_items[:pod1].data.merge(
      { title: "Pod Save America" }), config.fetch(:item))
  @all_items[:pod1_half] = Readstat::Item.create(
    all_items[:pod1].data.merge(
      { perusals: [{ date_started:   "2020-08-24",
                     date_finished:  "2020-08-24",
                     progress:  50 }] }), config.fetch(:item))

  # create files before all tests
  Files.constants.each do |const|
    IO.write("#{const.to_s.downcase}.csv", Files.const_get(const))
  end

  # then delete them afterward
  Minitest.after_run do
    Files.constants.each do |const|
      File.delete("#{const.to_s.downcase}.csv")
    end
  end

  def all_items
    self.class.all_items
  end

  def setup
    self.class.clear_err_log
  end

  def load_library(path)
    Readstat::Library.load(File.open(path),
                           config.fetch(:load),
                           config.fetch(:item),
                           &err_block)
    rescue Errno::ENOENT
      raise Readstat::FileError.new(path, label: "File not found!")
  end

  def invalid_line(path, items = [])
    loaded = load_library(path).items
    assert_equal items, loaded
    refute err_log.empty?
    refute err_log.all? { |error| error.is_a? Readstat::Warning }
  end

  def warned_line(path, items = [])
    loaded = load_library(path).items
    assert_equal items, loaded
    refute err_log.empty?
    assert err_log.all? { |error| error.is_a? Readstat::Warning }
  end

  def test_typical
#    skip
    items = all_items.slice(:metz, :milton, :metz_reread, :jedi).values # in order of date finished
    assert_equal items, load_library("typical.csv").items
  end

  def test_headers_and_headings_are_optional
#    skip
    items = all_items.slice(:metz, :milton, :metz_reread, :jedi).values
    assert_equal items, load_library("omit_headings.csv").items
  end

  def test_grouped_items_on_same_line
#    skip
    items = all_items.slice(:pod1, :pod3, :pod2).values # in order of title, since dates are same
    assert_equal items, load_library("grouped_items.csv").items
  end

  def test_dnf_percent
#    skip
    items = [all_items[:pod1_half]]
    assert_equal items, load_library("dnf_percent.csv").items
  end

  def test_dnf_percent_applies_to_all_perusals
#    skip
    items = [all_items[:pod1_half],
             all_items[:pod1_half].with_dates("2020-12-01", "2020-12-01")]
    assert_equal items, load_library("dnf_percent_with_rereads.csv").items
  end

  def test_dnf_date_percent
#    skip
    items = [all_items[:pod1_half],
             all_items[:pod1].with_dates("2020-12-01", "2020-12-01")]
    assert_equal items, load_library("dnf_percents_in_dates.csv").items
  end

  def test_dates_can_be_in_ascending_or_descending_order
#    skip
    items = all_items.slice(:metz, :metz_reread).values
    assert_equal items, load_library("dates_reverse_order.csv").items
  end

  def test_may_omit_some_dates_started_for_single_days
#    skip
    items = [all_items[:pod3],
             all_items[:pod3].with_dates("2021-01-01", "2021-01-01"),
             all_items[:pod3].with_dates("2021-02-01", "2021-02-01")]
    assert_equal items, load_library("omit_some_dates_started.csv").items
  end

  def test_may_omit_all_dates_started_for_single_days
#    skip
    items = [all_items[:pod2],
             all_items[:pod2].with_dates("2021-01-01", "2021-01-01")]
    assert_equal items, load_library("omit_all_dates_started.csv").items
  end

  def test_sources_can_be_indicated_variously
#    skip
    items = all_items.slice(:sources_1, :sources_2, :sources_3, :sources_4).values
    assert_equal items, load_library("sources.csv").items
  end

  def test_cannot_have_more_than_one_ISBN
#    skip
    invalid_line("two_isbns.csv")
  end

  def test_extra_spaces_ok
#    skip
    items = [all_items[:milton]]
    assert_equal items, load_library("spaces_and_tabs.csv").items
  end

  def test_no_items_ok
#    skip
    items = [all_items[:milton]]
    assert_equal items, load_library("spaces_and_tabs.csv").items
  end

  def test_error_if_file_not_found
#    skip
    assert_raises(Readstat::FileError) do
      load_library("nonexistent_file.csv")
    end
  end

  def test_skip_item_unless_all_columns_present_except_notes
#    skip
    invalid_line("missing_column.csv", [all_items[:pod3]])
  end

  def test_skip_item_if_name_genre_or_length_are_blank
#    skip
    invalid_line("blank_column_error.csv")
  end

  def test_skip_item_if_title_in_name_is_blank
#    skip
    invalid_line("blank_title_error.csv")
  end

  def test_warn_about_any_other_blanks
#    skip
    warned_line("blank_column_warning.csv", [all_items[:blank]])
  end

  def test_dont_warn_about_other_blanks_if_status_is_current_or_will
#    skip
    items = all_items.slice(:blank_current, :blank_will).values
    assert_equal items, load_library("blank_column_no_warning_for_current_or_will.csv").items
  end

  def test_nonsense_input_OK_unless_rating_or_dates_or_length
#    skip
    items = [all_items[:nonsense]]
    assert_equal items, load_library("valid_nonsense.csv").items
  end

  def test_invalid_rating
#    skip
    invalid_line("invalid_rating.csv")
  end

  def test_invalid_dates_unparsable
#    skip
    invalid_line("invalid_dates_parse.csv")
  end

  def test_invalid_dates_bad_count
#    skip
    invalid_line("invalid_dates_count.csv")
  end

  def test_invalid_dates_bad_order
#    skip
    invalid_line("invalid_dates_order.csv")
  end

  def test_invalid_length
#    skip
    invalid_line("invalid_length.csv")
  end
end
