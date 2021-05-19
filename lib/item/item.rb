# frozen_string_literal: true

require_relative "../errors"
require_relative "../util"
require_relative "validate"
require_relative "length"
require_relative "date"
require_relative "perusal"

module Readstat
  # an Item is a book, film, etc.
  class Item
    @new_id = 0
    attr_reader :id, :fields
    attr_private :config_item
    private_class_method :new

    def self.create(data, config_item, line = "", warn: true, id: nil, &err_block)
      validate = Item::Validate.new(config_item.fetch(:validate),
                                    config_item.fetch(:length),
                                    config_item.fetch(:sources),
                                    &err_block)
      data = filled_in(data, config_item.fetch(:template))
      validated_data = validate.call(data, line, warn: warn)
      new(validated_data, config_item, id)
    end

    private_class_method def self.filled_in(data, template)
      return data if template.nil?
      data = template.merge(data) do |_field, from_template, from_data|
        from_data.nil? ? from_template : from_data
      end
      data.merge({ perusals: filled_in_perusals(data[:perusals], template) })
    end

    private_class_method def self.filled_in_perusals(perusals, template)
      return perusals unless perusals.all? { |perusal| perusal.is_a? Hash }
      perusals.map do |perusal|
        template[:perusals].first.merge(perusal) do |_key, from_template, from_data|
          from_data.nil? ? from_template : from_data
        end
      end
    end

    def initialize(new_data, config_item, id = nil)
      @config_item = config_item
      @fields = new_data.keys
      @fields.each do |field|
        singleton_class.attr_reader(field) unless methods.include?(field)
        # alias plural fields in the singular, so that "count genre" command
        # works as well as "count genres".
        if field.to_s.chars.last == "s"
          singleton_class.alias_method(field.to_s.chop, field) \
            unless methods.include?(field.to_s.chop)
        end
      end
      self.data = new_data
      @id = id || self.class.new_id
    end

    def self.new_id
      @new_id += 1
    end

    def single_perusal
      raise ConsolidatedItemError if perusals.count > 1
      perusals.first
    end

    def status
      single_perusal.status
    end

    def done_dnf?
      status == :done || status == :dnf
    end

    def length
      @length * (perusals.map(&:progress).max / 100.0)
    end

    # def length_total  # will be needed later?
    #   @length
    # end

    def pages_per_day
      return 0 unless date_started && date_finished
      length / ((date_finished - date_started).to_f + 1)
    end

    alias speed pages_per_day

    # only for a split Item (no rereads)
    def date_started
      single_perusal.date_started
    end

    def date_finished
      single_perusal.date_finished
    end

    def progress
      single_perusal.progress
    end

    def date_added
      perusals.first.date_added
    end

    def dates_started
      perusals.map(&:date_started)
    end

    def dates_finished
      perusals.map(&:date_finished)
    end

    # also, with a :done status if a finish date is given
    def with_perusal(perusal)
      data_changes = { perusals: [perusal] }
      new_data = data(data_changes)
      self.class.create(new_data, config_item, id: id)
    end

    def with_perusals(new_perusals)
      data_changes = { perusals: new_perusals }
      new_data = data(data_changes)
      self.class.create(new_data, config_item)
    end

    def with_dates(new_date_started, new_date_finished)
      with_perusal(Perusal.create(date_added, new_date_started,
                                  new_date_finished, progress))
    end

    def with_length(new_length)
      data_changes = { length: new_length }
      new_data = data(data_changes)
      self.class.create(new_data, config_item)
    end

    def split_rereads
      return self unless perusals.count > 1
      perusals.map do |perusal|
        with_perusal(perusal)
      end
    end

    def split_months
      monthly_items = []
      remainder = self
      while remainder.multi_month?
        first_month, remainder = remainder.partition_at_first_month
        monthly_items << first_month
      end
      monthly_items << remainder
    end

    def self.consolidated(items)
      unless items.map(&:id).uniq.count == 1
        raise "Cannot consolidate Items with different IDs."
      end
      items.first.with_perusals(items.map(&:perusals).flatten.sort)
    end

    def initialize_copy(orig)
      self.data = orig.data
    end

    def ==(other)
      other.class == self.class && other.data == data
    end

    def data(updates = nil)
      copy = fields.map do |field|
        [field, instance_variable_get("@#{field}").dup]
      end.to_h
      updates.nil? ? copy : copy.merge(updates)
    end

    protected

    def data=(new_data)
      new_data.dup.each do |field, datum|
        instance_variable_set("@#{field}", datum)
      end
    end

    def multi_month?
      date_started.abs_month < date_finished.abs_month
    end

    # returns two Items:
    #   1. a copy with self's date started and the given date finished (and with
    #      length adjusted accordingly).
    #   2. the remainder Item.
    def partition_at_first_month
      end_of_month = Item::Date.new(date_started.year, date_started.month, -1)
      first_length = length *
                     ((end_of_month - date_started).to_f + 1) /\
                     ((date_finished - date_started).to_f + 1)
      first = with_dates(date_started, end_of_month)
              .with_length(first_length)
      remainder = with_dates(end_of_month + 1, date_finished)
                  .with_length(length - first.length)
      [first, remainder]
    end
  end
end
