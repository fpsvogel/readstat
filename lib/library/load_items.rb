# frozen_string_literal: true

require_relative "../util"
require_relative "../errors"
require_relative "../item/item"
require_relative "library"

# TODO: default column loading behavior, so that new columns and fields can easily be added
# TODO: then automatically make a new filter for each custom column

module Readstat
  using Blank

  class Library
    # feeds a file line by line, in the same way as String#each_line
    # class FileFeed
    #   attr_private_initialize :path

    #   def each_line(&block)
    #     IO.foreach(path) { |line| block.call(line) }
    #   rescue Errno::ENOENT
    #     raise FileError.new(path, label: "File not found!")
    #   end
    # end

    # LoadItems is a function that parses CSV lines into Items.
    class LoadItems
      using HashToAttr
      attr_private :config_load, :config_item, :cur_line

      def initialize(config_load, config_item)
        config_load.to_attr_private(self)
        @config_load       = config_load
        @config_item       = config_item
        @cur_line          = nil
      end

      # retuns Items in the same order as they arrive from feed
      def call(feed = nil, close_feed: true, &err_block)
        feed ||= File.open(path)
        items = []
        feed.each_line do |line|
          @cur_line = line.strip
          next if header? || comment? || blank_line?
          items += CSVLine.new(cur_line, config_load, config_item, &err_block)
                          .items
        rescue InvalidLineError, ValidationError => e
          err_block.call(e)
          next
        end
        items
      rescue Errno::ENOENT
        raise FileError.new(path, label: "File not found!")
      ensure
        feed&.close if close_feed && feed.respond_to?(:close)
        initialize(config_load, config_item) # reset to pre-call state
      end

      private

      def header?
        cur_line.start_with?(header_first)
      end

      def comment?
        cur_line.start_with?(comment_mark)
      end

      def blank_line?
        cur_line.empty?
      end

      # parses a line into an array of Item data
      class CSVLine
        using HashToAttr
        attr_private :line, :formats_regex
        attr_reader  :items

        def initialize(line, config_load, config_item, &err_block)
          config_load.merge(config_item.slice(:formats)).to_attr_private(self)
          @line          = line
          @formats_regex = formats.values.join("|")
          @items         = parse_items(config_item, &err_block)
        end

        private

        def parse_items(config_item, &err_block)
          split_multi_names(columns[:name]).map.with_index do |name, i|
            data = parse_item_data(columns, name, config_item.fetch(:template))
            Item.create(data, config_item, line, warn: i.zero?, &err_block)
            # i.zero?: warn only once for this line, in case of multiple items
          end.compact
        end

        def columns
          return @columns unless @columns.nil?
          @columns = csv_columns
                    .zip(line.split(column_separator))
                    .to_h
          raise InvalidLineError.new(line) if any_columns_missing?(@columns) ||
                                              any_important_columns_empty?(@columns)
          @columns
        end

        def any_columns_missing?(columns)
          columns.except(:notes).values.any?(&:nil?)
        end

        def any_important_columns_empty?(columns)
          columns.slice(:name, :genre, :length)
                .values.any? { |col| col.strip.empty? }
        end

        def split_multi_names(names_column)
          names_column
            .split(/\s*(?=#{formats_regex})/)
            .map { |name| name.strip.sub(/[,;]\z/, "") }
            .partition { |name| name.match?(/\A#{formats_regex}/) }
            .reject(&:empty?).first
        end

        def parse_item_data(columns, name, template)
          template.map { |field, _default| [field, send(field, columns, name)] }
                  .to_h
        end

        def rating(columns, _=nil)
          rating = columns[:rating].strip
          return nil if rating.empty?
          number = Integer(rating, exception: false) || Float(rating, exception: false)
          number \
          || (raise InvalidLineError.new(line))
        end

        def format(_=nil, name)
          icon = name.match(/^#{formats_regex}/).to_s
          formats.key(icon)
        end

        def author(_=nil, name)
          name.sub(/^#{formats_regex}/, "")
              .match(/.+(?=#{name_separator})/)
              &.to_s
              &.strip
        end

        def title(_=nil, name)
          name.sub(/^#{formats_regex}/, "")
              .sub(/.+#{name_separator}/, "")
              .presence \
              || raise(InvalidLineError.new(line))
        end

        def isbn_or_asin_alone_regex
          @isbn_regex ||= /(?:\d{3}[-\s]?)?[A-Z\d]{10}/
        end

        def isbn_or_asin_regex
          return @isbn_or_asin_regex unless @isbn_or_asin_regex.nil?
          isbn_lookbehind = "(?<=\\A|\\s|#{separator})"
          isbn_lookahead = "(?=\\z|\\s|#{separator})"
          @isbn_or_asin_regex = /#{isbn_lookbehind}#{isbn_or_asin_alone_regex.source}#{isbn_lookahead}/
        end

        def isbn(columns, _=nil)
          isbns = columns[:sources].scan(isbn_or_asin_regex)
          raise InvalidLineError.new(line) if isbns.count > 1
          isbns[0]&.to_s
        end

        # def isbn_prep(sources_str)
        #   sources_str.gsub(separator, " ")
        # end

        def isbns_and_urls_regex
          return @sources_regex unless @sources_regex.nil?
          isbn = "(#{isbn_or_asin_regex.source})"
          url_name = "([^#{separator}]+)"
          url = "(https?://[^\\s#{separator}]+)"
          url_prename = "#{url_name}#{name_separator}#{url}"
          url_postname = "#{url}#{name_separator}#{url_name}"
          @sources_regex = /#{isbn}|#{url_prename}|#{url_postname}|#{url}/
        end

        # TODO: (?<=^|\s|,)(?:\d{3}[-\s]?)?[A-Z\d]{10}(?=\s|,|\z)|[^,]+ - https?:\/\/[^\s,]+|https?:\/\/[^\s,]+ - [^,\n]+|https?:\/\/[^\s,]+
        def sources(columns, _=nil)
          #without_isbns = columns[:sources].gsub(isbn_or_asin_regex, "")
          #spaceless_sourcename_separator = "----"
          #without_isbns
          # columns[:sources]
          #   #.gsub(name_separator, spaceless_sourcename_separator)
          #   .split(sources_separator)
          #   .reject { |source| source.match?(isbn_or_asin_regex) }
          #   .map { |source| source.strip.split(name_separator) }
          #regex = /(?<=\A|\s|#{sep})((?:\d{3}[-\s]?)?[A-Z\d]{10})(?=\z|\s|#{sep})|([^#{sep}]+) - (https?:\/\/[^\s#{sep}]+)|(https?:\/\/[^\s#{sep}]+) - ([^#{sep}]+)|(https?:\/\/[^\s#{sep}]+)/
          urls = columns[:sources]
                  .scan(isbns_and_urls_regex)
                  .map(&:compact)
                  .reject { |source| source.first.match? isbn_or_asin_regex }
          names = columns[:sources]
                    .gsub(isbns_and_urls_regex, separator)
                    .split(separator)
                    .reject { |name| name.strip.empty? }
          urls + names
        end

        def sources_separator
          if columns[:sources].include? separator
            separator
          else
            /(?<=[^-\s])\s+(?=[^-\s])/
          end
        end

        def perusals(columns, _=nil)
          started = dates_started(columns) || []
          finished, progresses_in_dates = dates_finished(columns) || [[], []]
          started_finished =
            started_padded(started, finished)
            .zip(finished)
            .map { |start, finish| { date_started: start, date_finished: finish } }
          added = { date_added: date_added(columns) }
          return [added] if started_finished.count.zero?
          date_perusals = started_finished.tap { |dates| dates.first.merge!(added) }
          merge_progresses(columns, date_perusals, progresses_in_dates)
        end

        def started_padded(started, finished)
          return started if started.count >= finished.count
          pad_length = finished.count - started.count
          started + ([nil] * pad_length)
        end

        def merge_progresses(columns, date_perusals, progresses_in_dates)
          if progresses_in_dates.compact.presence
            final_progresses = progresses_in_dates
            # DNF must not be indicated in the two columns at the same time
            raise(InvalidLineError.new(line)) unless progress(columns[:name]).nil?
          else
            final_progresses = [progress(columns[:name])] * date_perusals.count
          end
          date_perusals.map.with_index do |dates, i|
            dates.merge({ progress: final_progresses[i] })
          end
        end

        def dnf_regex
          /\ADNF\s*(?:(?<progress>\d\d?)%\s*)?/
        end

        def progress(str)
          dnf = str.strip.match(dnf_regex)
          return nil if dnf.nil?
          return 0 if dnf[:progress].nil?
          dnf[:progress].to_i
        end

        def date_added(columns)
          return nil unless columns[:dates_started].strip.present?
          added = columns[:dates_started]
                  .match(/.+(?=#{date_added_separator})/)
                  &.to_s
                  &.then { |str| to_date_strings(str) }
          raise InvalidLine.new(line) if added && added.count > 1
          added&.first
        end

        def dates_started(columns)
          return nil unless columns[:dates_started].strip.present?
          columns[:dates_started]
            .sub(/.+#{date_added_separator}/, "")
            .then { |str| to_date_strings(str) }
        end

        def dates_finished(columns)
          return nil unless columns[:dates_finished].strip.present?
          progresses = []
          dates = to_date_strings(columns[:dates_finished]) do |raw_date|
            progresses << progress(raw_date)
            raw_date.strip.sub(dnf_regex, "")
          end
          [dates, progresses]
        end

        def to_date_strings(dates_str, &process_raw_date)
          dates_str.strip.split(/#{separator}\s*/).map do |date|
            date_hyphenated = date.gsub(date_separator, "-")
            process_raw_date&.call(date_hyphenated) || date_hyphenated
          end.presence
        end

        def genres(columns, _=nil)
          columns[:genres]
            .split(separator)
            .map(&:strip)
            .map(&:presence)
            .compact.presence \
            || raise(InvalidLineError.new(line))
        end

        def length(columns, _=nil)
          len = columns[:length].strip
          len.match(/\d+:\d\d/)
            .to_s.presence \
            || Integer(len, exception: false) \
            || raise(InvalidLineError.new(line))
        end

        def notes(columns, _=nil)
          columns[:notes]
            &.gsub(notes_newline, "\n")
            &.chomp
            &.sub(/#{notes_newline.chop}\z/, "")
        end
      end
    end
  end
end
