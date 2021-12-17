# frozen_string_literal: true

require_relative "../util"
require_relative "../errors"
require_relative "parsable"
require_relative "filter"
require_relative "../item/length"
require_relative "../result"
require_relative "help"

module Reading
  # a Command is a CLI command such as "average" or "list".
  class Command < Parsable
    using MapExtractFirst
    attr_reader :arg, :all_args, :filters, :output_options, :number_arg,
                :short_name, :lib, :superquery, :description, :takes_number_arg
    private_class_method :new
    attr_private :short_args, :arg_prefix,
                 :run, :run_special,
                 :run_items_and_data, :return_raw_data,
                 :item_lengths, :item_formats, :superqueries_order

    class << self
      attr_accessor :help_examples

      def parse(input, config_item)
        input = input.split(" ") unless input.is_a? Array
        if input.first == "help"
          if input.length > 1
            raise InputError, "The help command does not take any arguments."
          end
          help
        else
          input_preparsed = Filter.preparse(preparse(input))
          cmd_hash, input_without_cmd = super(input_preparsed)
          if cmd_hash.empty?
            raise InputError, 'Invalid input! Enter "help" to see valid input.'
          end
          cmd_hash.values.first.parse_remainder(input_preparsed,
                                                input_without_cmd, config_item)
        end
      end

      def one_per_input
        true
      end

      def help
        @help ||= Help.new(all, Filter.all, Option.all, help_examples)
      end
    end

    def initialize(name, all_args, description,
                   args_can_be_plural: false,
                   takes_number_arg: false,
                   default_number_arg: 1,
                   optional_arg_prefix: "",
                   default_arg: nil)
      @name = name.to_sym
      @all_args = all_args
      @description = description
      @short_name = find_unused_short_name(name)
      @short_args = find_unused_short_args
      @args_can_be_plural = args_can_be_plural
      @takes_number_arg = takes_number_arg
      @default_number_arg = default_number_arg
      @arg_prefix = optional_arg_prefix
      @default_arg = default_arg
    end

    # TODO: adjust automatic short name & short args to avoid conflict if there
    # are multiple commands/args with same initial letter.
    def find_unused_short_name(name)
      name.to_s[0].to_sym
    end

    def find_unused_short_args
      @all_args.map { |arg| arg.to_s[0].to_sym }
    end

    def specify(preparse: nil,
                run:,
                run_special: {},
                consolidate_rereads: true,
                special_data: {},
                wrap_per_day: nil,
                superquery: nil,
                run_items_and_data: false)
      @preparse = preparse
      @run = run
      @run_special = run_special
      @consolidate_rereads = consolidate_rereads
      @special_data = special_data
      @wrap_per_day = wrap_per_day
      @superquery = superquery
      @run_items_and_data = run_items_and_data
    end

    def active(filter_name)
      defaults = {
        format: item_formats,
        genre: items.map(&:genres).flatten.uniq,
        source: items.map(&:sources).flatten.map(&:name).uniq,
        rating: [5, 4, 3, 2, 1],
        length: lib.config_item.fetch(:lengths).map do |label, arr|
          Item::LengthRange.new(arr[0], arr[1],
                                lib.config_item.fetch(:length),
                                label: label)
        end,
        timespan: default_timespan_value
      }
      filters&.dig(filter_name)&.value || defaults[filter_name]
    end

    def set_filter(name, value_or_filter)
      filters[name] = if value_or_filter.is_a? Filter
                        value_or_filter
                      else
                        Filter.get(name).with_value(value_or_filter)
                      end
    end

    def query(superqueries = all_superqueries, label: nil)
      result = superqueries&.first&.call(self, superqueries[1..-1]) || simple_query
      label.nil? ? result : { label => result }
    end

    def parse_remainder(input_preparsed, input_without_cmd, config_item)
      number_arg, input_without_number = extract_number_arg(input_without_cmd)
      arg, input_without_arg = extract_arg(input_without_number)
      filters, input_without_filters = Filter.parse(input_without_arg, config_item)
      output_options, input_final_remainder = Option.parse(input_without_filters)
      unless input_final_remainder.empty?
        raise InputError, 'Invalid input! Enter "help" to see examples.'
      end
      @superqueries_order = detect_superqueries_order(input_preparsed, filters)
      @item_formats = config_item.fetch(:formats).keys
      with_args(arg, filters, output_options, number_arg)
    end

    def result(lib, return_raw_data: false)
      @lib = lib
      @return_raw_data = return_raw_data
      Result.new(query, self)
    end

    def wrap_per_day
      @wrap_per_day&.dig(arg)
    end

    protected

    def regex
      @regex ||= /\A(?:#{name}|#{short_name})\z/
    end

    # achieves an immutable public interface like in Item, but with a shortcut
    # using protected (mutating) setters.
    def with_args(arg, filters, output_options, number_arg = nil)
      copy = dup
      copy.arg = arg
      copy.number_arg = number_arg || @default_number_arg
      copy.filters = filters
      copy.output_options = output_options
      copy
    end

    def arg=(new_arg)
      @arg = new_arg
    end

    def number_arg=(new_number_arg)
      @number_arg = new_number_arg
    end

    def filters=(new_filters)
      @filters = new_filters
    end

    def output_options=(new_output_options)
      @output_options = new_output_options
    end

    def detect_superqueries_order(input, filters)
      sups = ([self] + filters.values).reject { |obj| obj.superquery.nil? }
      sups = sups.sort_by { |obj| obj.input_position(input) }
                 .map(&:name)
      sups
    end

    def extract_number_arg(input)
      number_arg, input_without_number = input.map_extract_first do |word|
        num = Integer(word, exception: false)
        num unless num.nil? || num >= 1970 # 1970 and upward are parsed as a year filter
      end
      [number_arg, input_without_number]
    end

    def extract_arg(input)
      input_singular = singularize(input)
      arg, input_without_arg, arg_index = input_singular.map_extract_first do |word|
        index = all_args.index(word.delete_prefix("#{arg_prefix} ").to_sym) ||
                  short_args.index(word.to_sym)
        all_args[index] unless index.nil?
      end
      if arg.nil?
        raise InputError, 'Missing argument. See "help" for examples.'
      end
      if input_without_arg[arg_index - 1] == arg_prefix
        input_without_arg.delete_at(arg_index - 1)
      end
      [arg, input_without_arg]
    end

    def singularize(input)
      input.map { |word| word[-1] == "s" ? word.chop : word }
    end

    def all_superqueries
      ([[name, superquery]] + filters.values.map { |f| [f.name, f.superquery] })
        .to_h
        .compact
        .sort_by { |name, _superquery| superqueries_order.index(name) }
        .map(&:last)
    end

    def simple_query
      data = special_data || items_data
      return data if return_raw_data
      result = run_special[arg]&.call(preprocess(data), self) ||
               run.call(preprocess(data), self)
      wrap_per_day&.call(result) || result
    end

    def special_data
      return nil if @special_data.nil?
      @special_data.respond_to?(:call) ? @special_data.call(self) : @special_data[arg]&.call(self)
    end

    def items_data#(&custom_datum)
      items.map { |item| [item, item.send(arg)] }.to_h
    end

    def items
      lib.items(filters)
    end

    def preprocess(data)
      preprocessed = if consolidate_rereads(arg)
                       by_id = data.group_by { |item, _datum| item.id }
                       by_id.map { |_id, items_and_data| items_and_data.last }.to_h
                     else
                       data
                     end
      if run_items_and_data
        preprocessed
      else
        preprocessed.values
      end
    end

    def consolidate_rereads(arg)
      return @consolidate_rereads if [true, false].include? @consolidate_rereads
      @consolidate_rereads[arg]
    end

    def default_timespan_value
      start_date = items.map(&:date_started).min || Date.parse("1970-01-01")
      end_date = items.map(&:date_finished).max || Date.today
      start_date..end_date
    end
  end
end
