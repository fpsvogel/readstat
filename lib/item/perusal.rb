# frozen_string_literal: true

require_relative "../util"
require_relative "date"

module Readstat
  class Item
    # a Perusal represents when an Item was consumed. e.g. a first reading and a
    # later rereading of a book would be two Perusals.
    class Perusal
      include Comparable

      attr_reader :status, :date_added, :date_started, :date_finished, :progress
      private_class_method :new

      def self.create(date_added, date_started, date_finished, progress)
        validated_dates = parse_date_strings([date_added,
                                              date_started, date_finished])
                          .then { |dates| fill_omitted_start_date(dates) }
                          .then { |dates| verify_dates_are_in_order(dates) }
        new(*validated_dates, progress)
      end

      def initialize(date_added, date_started, date_finished, progress)
        @date_added = date_added || NilDate.new
        @date_started = date_started || NilDate.new
        @date_finished = date_finished || NilDate.new
        @status = if !@date_finished.nil?
                    :done
                  elsif !@date_started.nil?
                    :current
                  else
                    :will
                  end
        @progress = progress || (if status == :done
                                    100
                                  else 0; end)
      end

      def <=>(other)
        a = [date_started, date_finished, date_added, progress]
        b = [other.date_started, other.date_finished,
             other.date_added, other.progress]
        # because a <=> b mysteriously results in nil...
        a.each_with_index do |el, i|
          sub_compare = el <=> b[i]
          return sub_compare unless sub_compare.zero?
        end
        0
      end

      def blank?
        date_added.nil? && date_started.nil? && date_finished.nil?
      end

      class << self
        private

        def parse_date_strings(dates)
          dates.map do |str_or_date|
            if str_or_date.is_a?(String)
              Item::Date.parse(str_or_date)
            else str_or_date; end
          end
        rescue ::Date::Error
          raise InvalidDateError
        end

        def fill_omitted_start_date(dates)
          dates[1] ||= dates[2]
          dates
        end

        def verify_dates_are_in_order(dates)
          raise InvalidDateError unless dates.reject(&:nil?) # to remove NilDate
                                             .chunk_while { |a, b| a <= b }
                                             .to_a.count < 2
          dates
        end
      end
    end
  end
end
