# frozen_string_literal: true

require_relative "../util"

module Readstat
  class Item
    # a Source represents where an Item was acquired.
    class Source
      attr_reader :name, :url

      # a name and\or URL can be passed, in either order
      def initialize(name_or_url, remainder = nil, names_from_urls: nil)
        assign_name_and_url([name_or_url.strip, remainder&.strip])
        auto_name_from_url(names_from_urls)
        @url.chop! if url&.chars&.last == "/"
      end

      def ==(other)
        return false unless other.is_a? Source
        name == other.name && url == other.url
      end

      protected

      def assign_name_and_url(name_and_url)
        if valid_url? name_and_url[0]
          if valid_url? name_and_url[1]
            raise ArgumentError, "Each Source must have only one one URL."
          end
          name_and_url.reverse!
        elsif !valid_url?(name_and_url[1]) && !name_and_url[1].nil?
          raise ArgumentError, "Invalid URL, or each Source must have only one one name."
        end
        @name = name_and_url[0]
        @url = name_and_url[1]
      end

      def valid_url?(str)
        str&.match?(/http[^\s,]+/)
      end

      def auto_name_from_url(names_from_urls)
        return if url.nil?
        names_from_urls&.each do |url_regex, auto_name|
          if url.match? url_regex
            @name = auto_name
            break
          end
        end
        @name = default_name_for_url if name.nil?
      end

      def default_name_for_url
        "site"
      end
    end
  end
end
