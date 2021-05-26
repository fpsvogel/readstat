# frozen_string_literal: true

require_relative "util"
require_relative "errors"
require_relative "parsable/command"
require_relative "parsable/filter"
require_relative "parsable/option"
require_relative "library/library"
require_relative "item/length"
require_relative "item/date"
require "date"

module Readstat
  using Blank

  class CLI
    class << self
      protected

      def command(*args, **kw)
        Command.create(*args, **kw)
      end

      def filter(*args, **kw)
        Filter.create(*args, **kw)
      end

      def output_option(*args, **kw)
        Option.create(*args, **kw)
      end

      def specify(name, *args, **kw)
        parsable = [Command, Filter, Option].map { |p| p.get(name) }
                                            .compact.first
        parsable.specify(*args, **kw)
      end

      def empty_or_zero?(obj)
        if obj.respond_to?(:empty?)
          obj.empty?
        elsif obj.respond_to?(:zero?)
          obj.zero?
        end
      end

      public

def load(config_item, config_output)

Command.help_examples = [
  ["top 5 ratings monthly 2019/5-2020",
    "# This date range goes to the end of 2020."],
  ["2019/5-2020 monthly 5 top ratings",
    "# The same command as above—the order of words does not matter."],
  ['list by rating search="PBS Frontline" genre=history,politics',
    "# No spaces allowed in filters, except in phrases in quotes!"]
]

command :average,
        %i[rating length amount],
        "Show average"

command :count,
        %i[rating length genre format source],
        "Show counts",
        args_can_be_plural: true

command :top,
        %i[rating length amount speed],
        "Show highest value(s)",
        args_can_be_plural: true,
        takes_number_arg: true,
        default_number_arg: 3

command :bottom,
        %i[rating length amount speed],
        "Show lowest value(s)",
        args_can_be_plural: true,
        takes_number_arg: true,
        default_number_arg: 3

command :list,
        %i[rating length genre],
        "List and sort items",
        optional_arg_prefix: "by",
        args_can_be_plural: true,
        default_arg: :rating

filter  :search,
        ['search="TERMS"', "show items whose Name column includes any " \
          "of the specified search term(s)."]

filter  :interval,
        ["monthly/yearly", "show data for each month or year"],
        [/(monthly)/, /(yearly)/]

filter  :by_genre,
        ["by genre OR genrely", "show data for each genre"],
        /(by\s?genres?|genrely)/

filter  :format,
        ["format=FORMAT[,FORMAT,…]", "show items of the specified " \
          "format(s). Use != for NOT."]

filter  :genre,
        ["genre=GENRE[,GENRE,…]", "show items of any of the specified " \
          "genre(s). Use != for NOT, double quotes for phrases."]

filter  :source,
        ["source=SOURCE[,SOURCE,…]", "show items from any of the specified " \
          "source(s). Use != for NOT, double quotes for phrases."]

filter  :rating,
        ["rating=#[,#,…]", "show items of any of the specified " \
          "rating(s). Use != for NOT."]

filter  :status,
        ["status=STATUS[,STATUS,…", "show items of any of the specified " \
          "status(es). Use != for NOT."],
        plural_ending: "es",
        default: [:done]

filter  :length,
        ["length=LENGTH[,LENGTH,…]", "show items of any of the specified length(s). Use != for NOT. "\
        + (config_item.fetch(:lengths)
                      .map do |label, length|
                        "#{label}: #{length.first}-#{length.last}"
                      end.join(", "))]

filter  :timespan,
        ["YYYY[/MM/DD][-YYYY/MM/DD]", "show items within a date range"],
        %r{(\d{4}(?:/\d?\d(?:/\d?\d)?)?)(?:(?:-)(\d{4}(?:/\d?\d(?:/\d?\d)?)?))?}

output_option :view,
              ["view=VIEW", "show results in the specified view: " \
              + config_output.fetch(:views).join(", ")],
              default: :table

output_option :unit,
              ["unit=UNIT", "show results in the specified unit: " \
              + config_output.fetch(:views).join(", ")]



specify :average,
        run: proc { |data|
          if data.nil? || data.empty? then 0
          else
            (data.reduce(:+) / data.count.to_f).round(2)
          end
        },
        consolidate_rereads: false,
        special_data: { amount: ->(cmd) { cmd.lib.amounts_per_day(cmd.filters) } },
        wrap_per_day: { amount: ->(avg) { Item::LengthPerDay.new(avg) } }


specify :count,
        run: proc { |data|
          if data.nil? then 0
          else data.count; end
        },
        consolidate_rereads: false,
        superquery: lambda { |cmd, superqueries|
          sort_hash_recursive = lambda do |hash|
            hash.sort_by do |label, inner|
              if inner.is_a? Hash
                sort_hash_recursive.call(inner)
                label
              else
                [inner, label]
              end
            end.reverse.to_h
          end

          sort = lambda do |results|
            if cmd.arg == :rating
              results.sort_by { |rating, _count| rating }
                     .reverse.to_h
            elsif cmd.arg == :length
              results.sort_by { |length_range, _count| length_range.begin }
                     .to_h
            else
              sort_hash_recursive.call(results)
            end
          end

          orig_filter = cmd.filters[cmd.arg]
          groups_to_count = cmd.active(cmd.arg)
          results = groups_to_count.map do |grouping|
            cmd.set_filter(cmd.arg, [grouping])
            cmd.query(superqueries, label: grouping)
          end
          cmd.set_filter(cmd.arg, orig_filter)
          # TODO: add option to show zeroes
          results = results.reduce({}, :merge)
                           .reject { |_grouping, result| empty_or_zero?(result) }
          sort.call(results)
        }

def ranked_items(items_and_data, number, order: :top, reject_zeroes: false)
  if items_and_data.nil? then []
  else
    items_and_data.sort_by do |item, datum|
                    [datum,
                      item.date_finished,
                      item.date_started,
                      item.date_added,
                      item.title]
                  end
                  .then do |list|
                    if reject_zeroes
                      list.delete_if { |item, data| data.pages.zero? }
                    else
                      list
                    end
                  end
                  .then do |list|
                    { top: list.reverse, bottom: list }[order]
                  end
                  .take(number)
                  .map do |item, datum|
                    author = "#{item.author} - " unless item.author.nil?
                    ["#{author}#{item.title} (#{item.date_finished})", datum]
                  end
                  .to_h
  end
end

def ranked_amounts(dates_and_data, number, order:)
  if dates_and_data.nil? then []
  else
    dates_and_data.sort_by do |date, length|
                    [length, date]
                  end
                  .then do |list|
                    { top: list.reverse, bottom: list }[order]
                  end
                  .take(number)
                  .to_h
                  .transform_keys(&:to_s)
  end
end

list_wrap_per_day = ->(list) { list.transform_values { |length| Item::LengthPerDay.new(length) } }

specify :top,
        run: proc { |items_and_data, cmd|
          ranked_items(items_and_data, cmd.number_arg, order: :top)
        },
        run_special:
        {
          amount: proc { |dates_and_data, cmd|
            ranked_amounts(dates_and_data, cmd.number_arg, order: :top)
          }
        },
        run_items_and_data: true,
        consolidate_rereads: { rating: true, length: true, amount: false, speed: false },
        special_data: { amount: ->(cmd) { cmd.lib.amounts_per_day(cmd.filters) } },
        wrap_per_day: { amount: list_wrap_per_day,
                        speed: list_wrap_per_day }


specify :bottom,
        run: proc { |items_and_data, cmd|
          raw = ranked_items(items_and_data, cmd.number_arg, order: :bottom,
                             reject_zeroes: cmd.arg == :length)
                # exclude zero-length items, which are caused by DNFs where no
                # percentage is set (because they default to 0%).
        },
        run_special:
        {
          amount: proc { |dates_and_data, cmd|
            ranked_amounts(dates_and_data, cmd.number_arg, order: :bottom)
          }
        },
        run_items_and_data: true,
        consolidate_rereads: { rating: true, length: true, amount: false, speed: false },
        special_data: { amount: ->(cmd) { cmd.lib.amounts_per_day(cmd.filters) } },
        wrap_per_day: { amount: list_wrap_per_day,
                        speed: list_wrap_per_day }


specify :list,
        run: proc { |list, cmd|
          list.flat_map { |entry| Array(entry[cmd.arg]).map { |datum| [datum, entry] } }
              .group_by(&:first)
              .sort.reverse
              .map do |group_key, data_and_entries|
                entries =
                  data_and_entries
                  .map(&:last)
                  .sort_by do |entry|
                    [entry[:dates_finished].max, entry[:title]]
                  end
                # print each date simply, not with Date#to_s
                entries.each do |entry|
                  entry[:dates_finished].define_singleton_method(:to_s) do
                    join(", ")
                  end
                end
                [group_key, entries]
              end
              .to_h
        },
        special_data: ->(cmd) { cmd.lib.list(cmd.filters) },
        consolidate_rereads: false


specify :search,
        run: proc { |f, item|
          target = f.downcase
          search_fields = [item.author, item.title]
          item if search_fields.any? { |field| field&.downcase&.include?(target) }
        },
        has_single_value: true


specify :interval,
        parse: proc { |f| f.first.to_sym },
        superquery: lambda { |cmd, superqueries|
          interval_ranges = lambda do
            interval_type = cmd.filters[:interval].value
            rounded_timespan = cmd.lib.round_dates(cmd.active(:timespan), interval_type)
            dates = rounded_timespan.select do |d|
              { yearly: d.month == 1 && d.day == 1,
                monthly: d.day == 1 }[interval_type]
            end
            months_skip = { yearly: 12, monthly: 1 }[interval_type]
            dates.map { |d| d..((d >> months_skip) - 1) }
          end

          label = lambda do |interval_range|
            trim_chars = { monthly: 3, yearly: 6 }[cmd.filters[:interval].value]
            interval_range.begin.to_s[0..-(trim_chars + 1)]
          end

          orig_filter = cmd.filters[:timespan]
          results = interval_ranges.call.map do |interval|
            cmd.set_filter(:timespan, interval)
            cmd.query(superqueries, label: label.call(interval))
          end
          cmd.set_filter(:timespan, orig_filter)
          # TODO: add option to show zeroes
          results.reduce({}, :merge)
                 .reject { |_interval, result| empty_or_zero?(result) }
        }


def join_by_and_genre(input)
  input.each_with_index do |word, i|
    next_word = input[i + 1]
    next unless word == "by" && next_word.match?(/genres?/)
    input[i] = "by #{next_word}"
    input.delete_at(i + 1)
  end
end

specify :by_genre,
        preparse: lambda { |input, _filter|
          join_by_and_genre(input)
        },
        superquery: lambda { |cmd, superqueries|
          orig_filter = cmd.filters[:genre]
          genres = cmd.active(:genre)
          results = genres.map do |genre|
            cmd.set_filter(:genre, [genre])
            cmd.query(superqueries, label: genre)
          end
          cmd.set_filter(:genre, orig_filter)
          # TODO: add option to show zeroes
          results.reduce({}, :merge)
                 .reject { |_genre, result| empty_or_zero?(result) }
                 .then do |hash|
                   if !hash.values.first.is_a?(Hash)
                     hash.sort_by { |_genre, result| result }
                         .reverse
                         .to_h
                   else
                     hash
                   end
                 end
        }


specify :format,
        not_mode_possible: true,
        parse: proc { |f| f&.split(",")&.map(&:to_sym) },
        run: proc { |f, item, not_mode| item if f.include?(item.format) ^ not_mode }


specify :genre,
        not_mode_possible: true,
        parse: proc { |f| f&.split(",") },
        run: proc { |f, item, not_mode| item if (item.genres & f).present? ^ not_mode }


specify :source,
        not_mode_possible: true,
        parse: proc { |f| f&.split(",") },
        run: proc { |f, item, not_mode|
          included_in_sources = item.sources.any? do |source|
            f.map(&:downcase).include?(source.name.downcase) ||
              f.any? { |str| str.include?(source.url) unless source.url.nil? }
          end
          item if included_in_sources ^ not_mode
        }


specify :rating,
        not_mode_possible: true,
        parse: proc { |f|
          f&.split(",")&.map do |str|
            Integer(str, exception: false) ||
              Float(str, exception: false) ||
              raise(InputError, '"rating" takes only numbers.')
          end
        },
        run: proc { |f, item, not_mode| item if Array(f).include?(item.rating) ^ not_mode }


specify :status,
        not_mode_possible: true,
        parse: proc { |f| f&.split(",")&.map(&:to_sym) },
        run: proc { |f, item, not_mode| item if (f.include?(item.status) || f.include?(:all)) ^ not_mode }


specify :length,
        not_mode_possible: true,
        parse: proc { |f, _config_item|
          f&.split(",")&.map do |length_input|
            from_config = config_item.fetch(:lengths)[length_input.to_sym]
            custom = length_input.split("-").map do |n|
              Integer(n, exception: false) || String(n)
            end
            length_array = from_config || custom
            config_length = config_item.fetch(:length)
            Item::LengthRange.new(length_array[0], length_array[1],
                                  config_length,
                                  label: (length_input unless from_config.nil?))
          rescue ArgumentError
            raise InputError, 'Invalid length range. Must be two lengths ' \
                              '(pages or hh:mm) with a hyphen in between.'
          end
        },
        run: proc { |f, item, not_mode|
          item if Array[f].flatten.any? { |range| range.include?(item.length) ^ not_mode }
        }


specify :timespan,
        run: proc { |f, item, _config_item, split_months|
          split_item = split_months ? item.split_months : [item]
          split_item.select { |subitem| f.include?(subitem.date_finished) }
        },
        parse: proc { |f|
          date_divider = "/"
          date_formats = { 3 => "%Y#{date_divider}%m#{date_divider}%d",
                           2 => "%Y#{date_divider}%m",
                           1 => "%Y" }

          expand_shortcuts = lambda do |dates|
            levels = f.last.scan(/#{date_divider}/).count + 1
            if levels < 3
              next_ = { 2 => :next_month, 1 => :next_year }[levels]
              dates[1] = dates.last.send(next_).prev_day
            end
            dates[1] = Item::Date.today if dates[1] > Item::Date.today
            dates[0]..dates[1]
          end

          validate = lambda do
            return nil unless f
            dates = f.map do |date_str|
              levels = date_str.scan(/#{date_divider}/).count + 1
              Item::Date.strptime(date_str, date_formats[levels])
            end
            raise InputError, "The second date must come after the first!"\
              if dates.count == 2 && dates.last < dates.first
            expand_shortcuts.call(dates)
          rescue ArgumentError
            raise InputError, "Invalid date!"
          end

          validate.call
        }
end
    end
  end
end
