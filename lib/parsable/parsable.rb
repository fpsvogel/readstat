# frozen_string_literal: true

require_relative "../util"
require_relative "../errors"

module Readstat
  using Blank

  # a Parsable is a word (more specifically a space-delimited sequence of
  # characters) entered in the CLI.
  class Parsable
    using MapExtractFirst
    attr_reader :name, :regex, :default, :value, :not_mode
    attr_private :parse, :has_single_value, :not_mode_possible
    private_class_method :new

    class << self
      def create(*args, **kw)
        obj = new(*args, **kw)
        all[obj.name] = obj
      end

      def get(key)
        all[key]
      end

      def preparse(input)
        input_preparsed = input
        all.each { |_name, obj| input_preparsed = obj.preparse(input_preparsed) }
        input_preparsed
      end

      def parse(input, config = nil)
        parsables, input_without_parsables = extract_parsables(input, config)
        parsables = parsables.map do |parsable|
          [parsable.name, parsable]
        end.to_h
        [parsables, input_without_parsables]
      end

      protected

      def all
        @all ||= {}
      end

      def extract_parsables(input, config)
        input_without_parsables = input
        my_parsables = all.each_with_object([]) do |(_name, parsable), my|
          break my if one_per_input && my.compact.present?
          new_value, new_not_mode, input_without_parsables =
            parsable.extract_value_from_input(input_without_parsables, config)
          my << parsable.with_value(new_value, new_not_mode)
        end.compact
        [my_parsables, input_without_parsables]
      end

      def one_per_input
        false
      end
    end

    def initialize
      raise NotImplementedError, "#{self.class} should have implemented #{__method__}"
    end

    def input_position(input_preparsed)
      match = input_preparsed.select { |word| match_captures(word) }
                             .first
      input_preparsed.index(match)
    end

    def extract_value_from_input(input, config)
      new_value, input_without_parsable = input.map_extract_first { |word| match_captures(word) }
      return [nil, nil, input] if new_value.nil?
      new_value, new_not_mode = parse_not(new_value) if not_mode_possible
      if has_single_value
        if new_value.count > 1
          raise InputError, "#{name} #{self.class.to_s.split("::").last.downcase}" \
            "takes only one value."
        end
        new_value = new_value.first
      end
      new_value = parse.call(new_value, config) unless parse.nil?
      [new_value, new_not_mode, input_without_parsable]
    end

    # achieves an immutable public interface like in Item, but with a shortcut
    # using protected (mutating) setters.
    def with_value(new_value = nil, new_not_mode = false)
      return nil if new_value.nil? && default.nil?
      copy = dup
      copy.value = new_value || default
      copy.not_mode = new_not_mode
      copy
    end

    def preparse(input)
      input_joined = join_phrases_in_quotes(input)
      @preparse&.call(input_joined, self) || input_joined
    end

    protected

    def value=(new_value)
      @value = new_value
    end

    def not_mode=(new_not_mode)
      @not_mode = new_not_mode
    end

    def match_captures(word)
      Array(regex).map do |single_regex|
        match = word.match(/^#{single_regex.source}$/)
        if not_mode_possible
          match&.named_captures&.compact&.transform_keys(&:to_sym)
        else
          match&.captures
        end
      end.compact.first&.compact
    end

    def parse_not(new_value)
      new_not_mode = new_value.keys.first == :not
      [new_value.values.first, new_not_mode]
    end

    def join_phrases_in_quotes(input_unjoined)
      input = input_unjoined.dup
      Array(regex).map do |single_regex|
        loop do
          phrase_start = input.index { |word| word.match?(single_regex) }
          break unless phrase_start && input[phrase_start].include?('"')
          phrase_end = phrase_end(input, phrase_start)
          input[phrase_start].sub!('"', "")
          input[phrase_end].sub!('"', "")
          join_from_start_to_end!(input, phrase_start, phrase_end)
        end
      end
      input
    end

    def phrase_end(input, phrase_start)
      phrase_end_el = input.select.with_index do |word, i|
        word.match?(/.+"(?:$|,)/) && i >= phrase_start
      end.first
      phrase_end = input.index(phrase_end_el)
      raise InputError, "Missing closing quote after a phrase." if phrase_end.nil?
      phrase_end
    end

    def join_from_start_to_end!(input, phrase_start, phrase_end)
      (phrase_end - phrase_start).times do
        input[phrase_start] << " #{input[phrase_start + 1]}"
        input.delete_at(phrase_start + 1)
      end
    end
  end
end
