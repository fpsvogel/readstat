# frozen_string_literal: true

require_relative "../util"

module Readstat
  class Item
    # a NilDate is for an Item's Perusal with no date specified, meaning it
    # either has not been started or has not been finished, so it is the most
    # recent in a sorted list of dates.
    class NilDate
      include Comparable

      def <=>(other)
        return 0 if other.is_a? NilDate
        1
      end

      def nil?
        true
      end
    end

    # a Date is for an Item's Perusal. NilDates are more recent in a sorted
    # list.
    class Date < ::Date
      def <=>(other)
        if other.is_a? NilDate
          -1
        else
          super
        end
      end

      def abs_month
        year * 12 + month
      end
    end
  end
end
