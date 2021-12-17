# frozen_string_literal: true

require_relative "../util"
require "forwardable"
require "bigdecimal"

module Reading
  class Item
    # a LengthPerDay is a wrapper around a Length, indicating pages/hours per
    # day, used for calculations involving amounts per day.
    class LengthPerDay
      extend Forwardable
      include Comparable
      def_delegators :@length, :to_f, :to_i
      attr_reader :length

      def initialize(length)
        @length = length
      end

      def to_s
        length.zero? ? "none" : "#{length} per day"
      end

      def <=>(other)
        length <=> other.length
      end

      def with_pages_output
        self.class.new(length.with_pages_output)
      end

      def with_hours_output
        self.class.new(length.with_hours_output)
      end
    end

    # a LengthRange is a wrapper around two Lengths, used for filtering Items
    # based on length.
    class LengthRange
      attr_reader :begin_length, :end_length, :label
      alias_method :begin, :begin_length
      alias_method :end, :end_length

      def initialize(begin_length, end_length, config_length = nil, label: nil)
        @begin_length = ensure_wrapped(begin_length, config_length)
        @end_length = ensure_wrapped(end_length, config_length)
        @label = label.to_s # short, medium, long, etc.
      end

      def include?(length)
        (begin_length.pages...end_length.pages).include? length.pages
      end

      def to_s
        label_prefix = label + ": " unless label.nil?
        "#{label_prefix}#{begin_length_to_s_without_unit} to #{end_length}"
      end

      def ==(other)
        begin_length == other.begin_length && end_length == other.end_length
      end

      def begin_length_to_s_without_unit
        begin_length.to_s[0...begin_length.to_s.rindex(" ")]
      end

      def with_pages_output
        self.class.new(begin_length.with_pages_output,
                       end_length.with_pages_output)
      end

      def with_hours_output
        self.class.new(begin_length.with_hours_output,
                       end_length.with_hours_output)
      end

      protected

      def ensure_wrapped(length, config_length)
        if length.is_a? Length
          length
        else
          Length.new(length, config_length)
        end
      end
    end

    # a Length is an Item's length in pages and/or hours.
    class Length
      extend Forwardable
      include Comparable

      attr_reader :pages, :hours, :type, :config_length, :output_type
      def_delegators :@pages, :zero?

      def initialize(length, config_length, type: nil, output_type: nil)
        if config_length.nil?
          raise ArgumentError, "config_length must not be nil."
        end
        @config_length = config_length
        @output_type = output_type
        if length.is_a? Numeric
          @type = type || :pages
          @pages = length
          @hours = length.to_f / config_length.fetch(:pages_per_hour)
        elsif length.is_a? String
          match = length.match(/(\d+):(\d\d)/)
          if match.nil?
            raise ArgumentError, "A length given as a String must be in " \
              "'hours:minutes' format."
          end
          @type = type || :hours
          hrs, min = match.captures
          @hours = hrs.to_i + min.to_i / 60.0
          @pages = @hours * config_length.fetch(:pages_per_hour)
        else raise ArgumentError
        end
      end

      def to_i
        send(output_type || :pages).to_i
      end

      def to_f
        send(output_type || :pages).to_f
      end

      def to_s
        return "#{format(output_type)} #{output_type}" unless output_type.nil?
        if type == :both
          "#{format(:pages)} pages or #{format(:hours)} hours"
        else
          "#{format(type)} #{type}"
        end
      end

      def format(type)
        return "infinity" if pages == Float::INFINITY
        number =  if pages.zero? ||
                      (type == :pages && pages > 1) ||
                      (type == :hours && hours >= 100)
                    send(type).round
                  elsif type == :hours && hours >= 0.1
                    send(type).round(1)
                  else
                    BigDecimal(send(type), 1).to_f
                  end
        commas(number)
      end

      def commas(number)
        number.to_s.reverse.scan(/(?:\d*\.)?\d{1,3}-?/).join(",").reverse
      end

      # empty because to_s is where it's rounded. this is called in a context
      # where the object could be a Float instead, which does need to be rounded
      # before its to_s.
      def round(_n = 0)
        self
      end

      def +(other)
        new_type = (type if other.type == type) || :both
        self.class.new(pages + other.pages, config_length, type: new_type)
      end

      def -(other)
        self.class.new(pages - other.pages, config_length, type: type)
      end

      def /(other)
        self.class.new(pages / other.to_f, config_length, type: type)
      end

      def *(other)
        self.class.new(pages * other.to_f, config_length, type: type)
      end

      def <=>(other)
        pages <=> other.pages
      end

      def with_pages_output
        self.class.new(pages, config_length, type: type, output_type: :pages)
      end

      def with_hours_output
        self.class.new(pages, config_length, type: type, output_type: :hours)
      end
    end
  end
end
