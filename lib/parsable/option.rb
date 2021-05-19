# frozen_string_literal: true

require_relative "parsable"

module Readstat
  class Option < Parsable
    private_class_method :new

    # class << self
    #   def parse(input, config = nil)
    #     options, input_without_options = extract_options(input, config)
    #     options = options.map do |option|
    #       [option.name, option]
    #     end.to_h
    #     [options, input_without_options]
    #   end

    #   protected

    #   def extract_options(input, config)
    #     input_without_options = input
    #     my_options = all.map do |_name, option|
    #       new_value, new_not_mode, input_without_options =
    #         option.extract_value_from_input(input_without_options, config)
    #       option.with_value(new_value, new_not_mode)
    #     end.compact
    #     [my_options, input_without_options]
    #   end
    # end

    def initialize(name, desc, regex = nil, plural_ending: "s", default: nil)
      @name = name.to_sym
      @desc = desc
      @regex = regex || default_regex(plural_ending)
      @default = default
      @not_mode = false
      @not_mode_possible = false
      @has_single_value = true
    end

    protected

    def default_regex(plural_ending)
      /#{name}(?:#{plural_ending})?!=(?<not>.+)|#{name}(?:#{plural_ending})?=(?<is>.+)/
    end
  end
end
