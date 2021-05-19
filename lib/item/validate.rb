# frozen_string_literal: true

require_relative "../util"
require_relative "../errors"
require_relative "length"
require_relative "perusal"
require_relative "sources"
require "io/console"

module Readstat
  class Item
    # Validate is a function that checks Item data, and possibly corrects it.
    class Validate
      using Blank
      using HashToAttr
      attr_private :warn_if_blank, :dont_warn_if_status,
                   :config_length, :config_sources, :err_block

      def initialize(config_validate, config_length, config_sources, &err_block)
        config_validate.to_attr_private(self)
        @config_length = config_length
        @config_sources = config_sources
        @err_block = err_block
      end

      # takes a hash item_data. returns valid data (a hash) or nil.
      def call(item_data, line, warn: true)
        item_data = item_data
          .then { |data| wrap_length(data) }
          .then { |data| wrap_sources(data) }
          .then { |data| wrap_perusals(data) }
          .then { |data| verify_perusals_have_enough_dates_finished(data) }
        warn_about_blanks(item_data, line) if warn
        item_data
      rescue InvalidDateError => e
        raise error_with_line(e, line)
      end

      protected

      def warn_about_blanks(data, line)
        blanks = warn_if_blank.select do |keys, _|
          blank_parts = data.values_at(*keys)
                            .map(&:presence)
                            .select(&:nil?)
                            .count
          blank_parts == keys.count # e.g. if [:isbn, :sources] is in
          # warn_if_blank, both must be missing for a warning to show.
        end.values
        return if blanks.empty? ||
          dont_warn_if_status.include?(data.fetch(:perusals).last.status) ||
          err_block.nil? # err_block is nil when creating an Item *after* the
          # library has been loaded (e.g. when splitting an Item). the warning
          # was already shown at load time.
        raise BlankFieldWarning.new(blanks)
      rescue BlankFieldWarning => e
        err_block.call(error_with_line(e, line))
      end

      def error_with_line(err, line)
        truncated_line = truncate(line,
                                  IO.console.winsize[1],
                                  padding: err.message.length)
        err.class.new(truncated_line, label: err.message)
      end

      def truncate(str, max, padding: 0, min: 30)
        end_index = max - padding
        end_index = min if end_index < min
        str.length + padding > max ? "#{str[0...end_index]}..." : str
      end

      def wrap_length(data)
        wrapped_length = if data.fetch(:length).is_a?(Length)
                          data.fetch(:length).dup
                        else Length.new(data.fetch(:length), config_length); end
        data.merge({ length: wrapped_length })
      end

      def wrap_sources(data)
        wrapped_sources = data.fetch(:sources).map do |raw_source|
          if raw_source.is_a?(Source)
            raw_source.dup
          else
            Source.new(*raw_source,
                       names_from_urls: config_sources.fetch(:names_from_urls))
          end
        end.sort_by { |source| source.name }
        data.merge({ sources: wrapped_sources })
      end

      def wrap_perusals(data)
        wrapped_perusals = data.fetch(:perusals).map do |raw_perusal|
          if raw_perusal.is_a?(Perusal)
            raw_perusal.dup
          elsif raw_perusal.is_a?(Hash)
            Perusal.create(*raw_perusal.values)
          else
            Perusal.create(*raw_perusal)
          end
        end.sort
        data.merge({ perusals: wrapped_perusals })
      end

      def verify_perusals_have_enough_dates_finished(data)
        raise InvalidDateError unless \
          data.fetch(:perusals).select { |p| p.status == :current }.count <= 1
        data
      end
    end
  end
end
