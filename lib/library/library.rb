# frozen_string_literal: true

require_relative "../util"
require_relative "../errors"
require_relative "load_items"
require_relative "../item/item"
require_relative "../item/date"
require_relative "../item/length"
require "forwardable"

module Readstat
  # Library is a container for Items, providing ways to retrieve Items and data
  # that spans across Items.
  class Library
    using Blank

    attr_reader :config_item

    def self.load(custom_feed = nil, config_load, config_item, &err_block)
      new(LoadItems.new(config_load, config_item)
                   .call(custom_feed, &err_block),
          config_item)
    end

    def initialize(items, config_item)
      @items = self.class.sort(items)
      @config_item = config_item
    end

    def self.sort(items)
      items.compact.flat_map(&:split_rereads).sort_by do |item|
        [item.date_finished, item.date_started, item.date_added, item.title]
      end
    end

    def items(filters = {}, split_months: false)
      raise NotInitializedError if @items.nil?
      return @items if filters.empty?
      @items.map do |item|
        filters.values.compact.each do |filter|
          item = Array(item).map do |subitem|
                              filter.run(subitem, config_item, split_months)
                            end
                            .flatten.compact
          break unless item.present?
        end
        item
      end.flatten.compact
    end

    def consolidated_items(filters)
      by_id = items(filters).group_by(&:id)
      by_id.map { |_id, sub_items| Item.consolidated(sub_items) }
    end

    def list(filters)
      consolidated_items(filters).map do |item|
        [item,
          { title:  item.title,
            rating: item.rating,
            length: item.length,
            genre: item.genres,
            dates_finished: item.perusals.map(&:date_finished) }]
      end.to_h
    end

    def amounts_per_day(filters = {})
      items_split = items(filters, split_months: true)
      zero_length_default = Hash.new do
        Item::Length.new(0, config_item.fetch(:length))
      end
      amounts = items_split.each_with_object(zero_length_default) do |item, result|
        (item.date_started..item.date_finished).each do |date|
          result[date] += item.pages_per_day
        end
      end
      return {} if amounts.empty?
      fill_in_with_zeroes(amounts, filters)
    end

    def round_dates(range, interval)
      return range.begin..range.end if interval == :daily
      round_date(range.begin, interval, :start)..\
        round_date(range.end, interval, :end)
    end

    protected

    def fill_in_with_zeroes(amounts, filters)
      default = round_dates(amounts.keys.min..amounts.keys.max,
                            filters[:interval] || :daily)
      timespan = filters[:timespan]&.value || default
      timespan.map { |date| [date, amounts[date]] }.to_h
    end

    def round_date(date, interval, pos)
      pos = { start: 1, end: -1 }[pos]
      if %i[monthly month].include?(interval)
        Item::Date.new(date.year, date.month, pos)
      elsif %i[yearly year].include?(interval)
        Item::Date.new(date.year, pos, pos)
      end
    end
  end
end
