# frozen_string_literal: true

require_relative "test_helper"
require_relative "test_base_with_items"

require "library/library"
require "util"

class CLITest < ReadstatTestWithItems
  using Blank

  @config = Readstat.config
  Readstat::CLI.load(@config.fetch(:item), @config.fetch(:output))
  @err_block = lambda do |err|
    @err_log << err
    #err.show
  end

  def setup
    self.class.clear_err_log
  end

  def run_command(input, items = basic_items.values, return_raw_data: false)
    Readstat::Command.parse(input, config.fetch(:item))
                     .result(Readstat::Library.new(items, config.fetch(:item)),
                             return_raw_data: return_raw_data)
                     .raw
  rescue Readstat::AppError => e; err_block.call(e)
  end

  # COMMANDS (perfect input, no options) # # # # # # # # # # # # # # # # # # # #

  def test_average_length
#    skip
    test_items = basic_done_dnf_items
    expected = (test_items.map(&:length).reduce(:+).to_f / test_items.count).round(2)
    assert_equal expected, run_command("average length", test_items).to_f
  end

  def test_abbreviated_command
#    skip
    test_items = basic_done_dnf_items
    expected = (test_items.map(&:length).reduce(:+).to_f / test_items.count).round(2)
    assert_equal expected, run_command("a l", test_items).to_f
  end

  def test_average_rating
#    skip
    test_items = basic_done_dnf_items.reject { |item| item.rating.nil? }
    expected = (test_items.map(&:rating).reduce(:+).to_f / test_items.count).round(2)
    assert_equal expected, run_command("average rating").to_f
  end

  def test_average_amount
#    skip
    test_items = items_split(:booklet, :prequel, :podcast)
    days = (test_items.map(&:date_finished).max - test_items.map(&:date_started).min).to_i + 1
    expected = (test_items.map(&:length).reduce(:+).to_f / days).round(2)
    assert_in_delta expected, run_command("average amount", test_items).to_f
  end

  def count_ratings(arg_form)
    test_items = basic_done_dnf_items
    expected = test_items.group_by(&:rating)
                         .sort.reverse.to_h
                         .transform_values(&:count)
    assert_equal expected.to_a, # to_a to check order
                 run_command("count #{arg_form}", test_items).to_a
  end

  def test_count_ratings
#    skip
    count_ratings("ratings")
  end

  def test_count_ratings_alt
#    skip
    count_ratings("rating")
  end

  def test_count_lengths
#    skip
    test_items = basic_done_dnf_items
    length_ranges = config.fetch(:item).fetch(:lengths).map do |label, arr|
      Readstat::Item::LengthRange.new(
        Readstat::Item::Length.new(arr[0], config.fetch(:item).fetch(:length)),
        Readstat::Item::Length.new(arr[1], config.fetch(:item).fetch(:length)),
        label: label)
    end
    expected = test_items.group_by do |item|
      length_ranges.select do |range|
        range.include?(item.length)
      end.first
    end
    expected = expected.sort_by { |length_range, _items| length_range.begin }
                       .to_h
                       .transform_values(&:count)
                       .reject { |_length, count| count.zero? }
    assert_equal expected.to_a, # to_a to check order
                 run_command("count lengths", test_items).to_a
  end

  def test_count_genres
#    skip
    test_items = basic_done_dnf_items
    expected = test_items.flat_map(&:genres)
                         .uniq
                         .map do |genre|
                           [genre,
                            test_items.select { |item| item.genres.include? genre }
                                      .count]
                         end
                         .sort_by { |genre, count| [count, genre] }
                         .reverse.to_h
    assert_equal expected.to_a, # to_a to check order
                 run_command("count genres", test_items).to_a
  end

  def test_count_formats
#    skip
    test_items = basic_done_dnf_items
    expected = test_items.group_by(&:format).to_h
                         .transform_values(&:count)
                         .sort_by { |format, count| [count, format] }
                         .reverse.to_h
    assert_equal expected.to_a, # to_a to check order
                 run_command("count formats", test_items).to_a
  end

  def with_one_source_each(items)
    items.flat_map do |item|
      sub_items = []
      while item.sources.count > 1
        sub_data_changes = { sources: [item.sources.last] }
        sub_new_data = item.data(sub_data_changes)
        sub_items << Readstat::Item.create(sub_new_data, config.fetch(:item))
        data_changes = { sources: item.sources[0..-2] }
        new_data = item.data(data_changes)
        item = Readstat::Item.create(new_data, config.fetch(:item))
      end
      sub_items.presence || item
    end
  end

  def test_count_sources
#    skip
    test_items = with_one_source_each(basic_done_dnf_items)
    expected = test_items.group_by { |item| item.sources.first&.name }
                         .reject { |source, _items| source.nil? }
                         .to_h
                         .transform_values(&:count)
                         .sort_by { |source, count| [count, source] }
                         .reverse.to_h
    assert_equal expected.to_a, # to_a to check order
                 run_command("count sources", test_items).to_a
  end

  def ranked_items(arg, number = 3, order:, plural: true, consolidate_rereads: true)
    test_items = basic_done_dnf_items.reject { |item| item.send(arg).nil? }
    all = test_items.map { |item| [item, item.send(arg)] }
          .sort_by do |item, datum|
            [datum,
            item.date_finished,
            item.date_started,
            item.date_added,
            item.title]
          end
    if consolidate_rereads
      all = all.group_by { |item, _datum| item.title }
               .map do |_group, data|
                 data.sort_by do |item, datum|
                   [datum,
                    item.date_finished,
                    item.date_started,
                    item.date_added,
                    item.title]
                 end
                 .then do |list|
                   { top: list.reverse, bottom: list }[order]
                 end
                 .first
               end
    end
    expected = all.map { |item, datum| ["#{item.title} (#{item.date_finished})", datum] }
                  .then do |list|
                    { top: list.reverse, bottom: list }[order]
                  end
                  .take(number)
                  .to_h
    if arg == "speed"
      expected.transform_values! { | length| Readstat::Item::LengthPerDay.new(length) }
    end
    actual = run_command("#{order} #{number} #{plural ? arg.to_s + "s" : arg}")
    assert_equal expected.to_a, actual.to_a
  end

  def ranked_amounts(number = 3, order:)
    test_items = basic_done_dnf_items
    amounts_per_day = Readstat::Library.new(test_items, config.fetch(:item))
                                       .amounts_per_day
    expected = amounts_per_day.sort_by do |date, length|
                                [length, date]
                              end
                              .then do |list|
                                { top: list.reverse, bottom: list }[order]
                              end
                              .take(number)
                              .to_h
                              .transform_keys(&:to_s)
                              .transform_values do |length|
                                Readstat::Item::LengthPerDay.new(length)
                              end
    actual = run_command("#{order} #{number} amounts")
    assert_equal expected.to_a, actual.to_a
  end

  def test_top_ratings
#    skip
    ranked_items("rating", order: :top)
  end

  def test_top_ratings_alt
#    skip
    ranked_items("rating", order: :top, plural: true)
  end

  def test_top_7_speeds
#    skip
    ranked_items("speed", 7, order: :top, consolidate_rereads: false)
  end

  def test_top_lengths
#    skip
    ranked_items("length", order: :top)
  end

  def test_top_amounts
#    skip
    ranked_amounts(order: :top)
  end

  def test_top_speeds
#    skip
    ranked_items("speed", order: :top)
  end

  def test_bottom_ratings
#    skip
    ranked_items("rating", order: :bottom)
  end

  def test_bottom_ratings_alt
#    skip
    ranked_items("rating", order: :bottom, plural: true)
  end

  def test_bottom_lengths
#    skip
    ranked_items("length", order: :bottom)
  end

  def test_bottom_amounts
#    skip
    ranked_amounts(order: :bottom)
  end

  def test_bottom_speeds
#    skip
    ranked_items("speed", order: :bottom)
  end

  def list(arg, custom_command: nil)
    test_items = items(:booklet, :prequel, :podcast, :docu, :movie, :tome)
    expected = test_items.map do |item|
      { title:  item.title,
        rating: item.rating,
        length: item.length,
        genre: item.genres,
        dates_finished: item.perusals.map(&:date_finished) }
    end
    expected = expected.flat_map { |entry| Array(entry[arg]).map { |datum| [datum, entry] } }
                       .group_by(&:first)
                       .sort.reverse
                       .map do |group_key, data_and_entries|
                         entries =
                           data_and_entries
                           .map(&:last)
                           .sort_by do |entry|
                             [entry[:dates_finished].max, entry[:title]]
                           end
                         entries.map! do |entry|
                           entry[:dates_finished] = entry[:dates_finished].join(", ")
                           entry
                         end
                         [group_key, entries]
                       end
                       .to_h
    actual = run_command(custom_command || "list by #{arg}", test_items)
    assert_equal expected.to_a, actual.to_a
  end

  def test_list_by_rating
#    skip
    list(:rating)
  end

  def test_list_by_rating_alt
#    skip
    list(:rating, custom_command: "list ratings")
  end

  def test_list_by_length
#    skip
    list(:length)
  end

  def test_list_by_genre
#    skip
    list(:genre)
  end

  # WITH OPTIONS # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  def deep_transform(obj, klass, &transform)
    if obj.is_a? Hash
      if obj.keys.first.is_a? klass
        deep_transform(obj.keys, klass, &transform)
      else
        obj.transform_values { |v| deep_transform(v, klass, &transform) }
      end
    elsif obj.is_a? Array
      obj.map { |v| deep_transform(v, klass, &transform) }
    elsif obj.is_a? klass
      transform.call(obj)
    else
      obj
    end
  end

  def filter_test(filter_str, expected_titles)
    raw_data = run_command("average length #{filter_str}", return_raw_data: true)
    if expected_titles.is_a? Array
      assert_equal expected_titles, raw_data.keys.map(&:title)
    elsif expected_titles.is_a? Hash
      assert_equal expected_titles, deep_transform(raw_data, Readstat::Item, &:title)
    end
  end

  def test_status_filter
#    skip
    filter_test("status=current,will", titles(:novel, :course, :to_watch))
  end

  def test_status_all_filter
#    skip
    filter_test("status=all", titles(*(%i[novel prequel] + basic_items_keys)))
  end

  def test_plural_option_filter
#    skip
    filter_test("statuses=current,will", titles(:novel, :course, :to_watch))
  end

  def test_not_option_filter
#    skip
    filter_test("status!=done", titles(:novel, :course, :to_watch))
  end

  def test_format_filter
#    skip
    filter_test("format=audio,video", titles(:novel, :podcast, :docu, :movie))
  end

  def test_rating_filter
#    skip
    filter_test("rating=3,2,1", titles(:booklet, :movie, :tome))
  end

  def test_length_filter
#    skip
    short_medium_keys = titles(:prequel, :booklet, :prequel, :podcast, :docu, :movie, :tome)
    filter_test("length=short,medium", short_medium_keys)
  end

  def test_manual_length_filter_pages
#    skip
    short_medium_keys = titles(:prequel, :booklet, :prequel, :podcast, :docu, :movie, :tome)
    filter_test("length=0-400", short_medium_keys) # TODO: bad input test
  end

  def test_manual_length_filter_hours
#    skip
    short_medium_keys = titles(:prequel, :booklet, :prequel, :podcast, :docu, :movie, :tome)
    filter_test("length=0-10:00", short_medium_keys) # TODO: bad input test
  end

  def test_search_filter
#    skip
    filter_test('search="j. r. r. tolkien"', titles(:novel, :prequel, :prequel))
  end

  def test_genre_filter
#    skip
    filter_test('genre=fiction,"nature show"', titles(:novel, :prequel, :booklet, :prequel, :docu, :movie, :tome))
  end

  def test_source_filter
#    skip
    filter_test('source="libro fm" status=done', titles(:novel))
  end

  def test_source_filter_multi
#    skip
    filter_test('source="libro fm","lexington public library",dvd', titles(:novel, :prequel, :prequel, :docu, :tome))
  end

  def genrely_filter(filter_form)
    filter_test("#{filter_form} genre=fiction,\"nature show\"",
      { "fiction"     => titles(:novel, :prequel, :booklet, :prequel, :tome),
        "nature show" => titles(:docu, :movie) })
  end

  def test_genrely_filter
#    skip
    genrely_filter("genrely")
  end

  def test_genrely_alt_filter
#    skip
    genrely_filter("by genre")
  end

  def test_monthly_interval_filter
#    skip
    filter_test("monthly", { "2015-12" => titles(:novel),
                             "2020-10" => titles(:prequel),
                             "2021-01" => titles(:booklet, :prequel, :podcast),
                             "2021-02" => titles(:docu, :movie),
                             "2021-03" => titles(:tome) })
  end

  def test_yearly_interval_filter
#    skip
    filter_test("yearly", { "2015" => titles(:novel),
                            "2020" => titles(:prequel),
                            "2021" => titles(:booklet, :prequel, :podcast, :docu, :movie, :tome) })
  end

  def test_timespan_filter_months
#    skip
    filter_test("2021/01-2021/02", titles(:booklet, :prequel, :podcast, :docu, :movie))
  end

  def test_timespan_filter_one_month
#    skip
    filter_test("2021/01", titles(:booklet, :prequel, :podcast))
  end

  def test_timespan_filter_years
#    skip
    filter_test("2015-2020", titles(:novel, :prequel))
  end

  def test_timespan_filter_one_year
#    skip
    filter_test("2020", titles(:prequel))
  end

  def test_average_amount_with_timespan_filter_splits_item_at_boundary
#    skip
    test_item = all_items[:booklet]
    days = 31
    expected = (test_item.length / 2).to_f / days
    assert_in_delta expected, run_command("average amount 2020/12", [test_item]).to_f
  end

  # VALID INPUT FLEXIBILITY # # # # # # # # # # # # # # # # # # # # # # # # # #

  def test_filter_before_command
#    skip
    item_a = all_items[:booklet]
    item_b = all_items[:tome]
    item_exclude = all_items[:docu]
    test_items = [item_a, item_exclude, item_b]
    expected = { "2021-01" => { "#{item_a.title} (#{item_a.date_finished})" => item_a.rating },
                 "2021-03" => { "#{item_b.title} (#{item_b.date_finished})" => item_b.rating } }
    actual = run_command("monthly top ratings format=print,ebook", test_items)
    assert_equal expected.to_a, actual.to_a
  end

  def test_argument_before_command
#    skip
    test_items = items(:booklet, :tome)
    expected = { 3 => 1, 1 => 1 }
    actual = run_command("ratings count", test_items)
    assert_equal expected.to_a, actual.to_a
  end

  def test_filter_in_middle
#    skip
    test_items = items(:booklet, :tome, :docu)
    expected = { 3 => 1, 1 => 1 }
    actual = run_command("ratings format=print,ebook count", test_items)
    assert_equal expected.to_a, actual.to_a
  end

  def test_filter_synonym_of_argument
#    skip
    item_a = all_items[:booklet]
    item_b = all_items[:tome]
    test_items = [item_a, item_b]
    expected =
      { "fiction" =>
        { "fiction" =>
          [{ title: "The Old Man and the Sea",
             rating: 3,
             length: item_a.length,
             genre: ["fiction"],
             dates_finished: item_a.dates_finished },
           { title: "Pamela: Or Virtue Rewarded",
             rating: 1,
             length: item_b.length,
             genre: ["fiction"],
             dates_finished: item_b.dates_finished }
          ]} }
    actual = run_command("list by genre by genre", test_items)
    assert_equal expected.to_a, actual.to_a
  end

  def test_synonym_resolved_by_first_possible_argument
#    skip
    item_a = all_items[:booklet]
    item_b = all_items[:tome]
    test_items = [item_a, item_b]
    expected =
      { "fiction" =>
        { 3 =>
          [{ title: "The Old Man and the Sea",
             rating: 3,
             length: item_a.length,
             genre: ["fiction"],
             dates_finished: item_a.dates_finished }],
          1 =>
          [{ title: "Pamela: Or Virtue Rewarded",
             rating: 1,
             length: item_b.length,
             genre: ["fiction"],
             dates_finished: item_b.dates_finished }
          ]} }
    actual = run_command("list ratings by genre", test_items)
    assert_equal expected.to_a, actual.to_a
  end

  def test_2_superqueries_run_in_input_order_a
#    skip
    test_items = items(:booklet, :tome)
    expected = { 3 => { "2021-01" => 1 },
                 1 => { "2021-03" => 1 } }
    # as long as "count" comes before "monthly":
    actual1 = run_command("count ratings monthly", test_items)
    actual2 = run_command("count monthly ratings", test_items)
    actual3 = run_command("ratings count monthly", test_items)
    assert_equal actual1.to_a, actual2.to_a
    assert_equal actual2.to_a, actual3.to_a
    assert_equal expected.to_a, actual1.to_a
  end

  def test_2_superqueries_run_in_input_order_b
#    skip
    test_items = items(:booklet, :tome)
    expected = { "2021-01" => { 3 => 1 },
                 "2021-03" => { 1 => 1 } }
    actual = run_command("monthly ratings count", test_items)
    # could also swap words around, as above
    assert_equal expected.to_a, actual.to_a
  end

  def test_3_superqueries_run_in_input_order_a
#    skip
    test_items = items(:booklet, :tome)
    expected = { 3 => { "2021-01" => { "fiction" => 1 } },
                 1 => { "2021-03" => { "fiction" => 1 } } }
    actual = run_command("count ratings monthly by genre", test_items)
    assert_equal expected.to_a, actual.to_a
  end

  def test_3_superqueries_run_in_input_order_b
#    skip
    test_items = items(:booklet, :tome)
    expected = { 3 => { "fiction" => { "2021-01" => 1 } },
                 1 => { "fiction" => { "2021-03" => 1 } } }
    actual = run_command("count ratings by genre monthly", test_items)
    assert_equal expected.to_a, actual.to_a
  end

  def test_3_superqueries_run_in_input_order_c
#    skip
    test_items = items(:booklet, :tome)
    expected = { "fiction" => { 3 => { "2021-01" => 1 },
                                1 => { "2021-03" => 1 } } }
    actual = run_command("by genre count ratings monthly", test_items)
    assert_equal expected.to_a, actual.to_a
  end

  # BAD INPUT # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  def no_command
   skip
  end

  def no_argument
   skip
  end

  def superfluous_words
   skip
  end

  def spaces_in_filter
   skip
  end

  def search_filter_missing_quotes
   skip
  end

  def search_filter_missing_one_quote
   skip
  end

  def format_filter_invalid
   skip
  end

  def genre_filter_nonexistent #??
   skip
  end

  def rating_filter_too_high
   skip
  end

  def rating_filter_negative
   skip
  end

  def rating_filter_decimal
   skip
  end

  def rating_filter_nonnumeric
   skip
  end

  def status_filter_invalid
   skip
  end

  def length_filter_invalid
   skip
  end

  def length_filter_bad_manual
   skip
  end

  def timespan_filter_invalid_date
   skip
  end

  def timespan_filter_future_date
   skip
  end
end
