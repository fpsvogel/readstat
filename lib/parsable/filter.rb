# frozen_string_literal: true

require_relative "../util"
require_relative "option"

module Reading

  # a Filter is an option entered in the CLI that is used to filter the results.
  class Filter < Option
    attr_reader :superquery
    private_class_method :new

    def specify(run: nil,
                parse: nil,
                preparse: nil,
                not_mode_possible: false,
                superquery: nil,
                has_single_value: false)
      @run = run
      @parse = parse
      @preparse = preparse
      @not_mode_possible = not_mode_possible
      @superquery = superquery
      @has_single_value = has_single_value
    end

    def run(item, *other_args)
      return item if @run.nil?
      all_other_args = other_args.dup
      all_other_args.unshift(not_mode) if not_mode_possible
      @run.call(value, item, *all_other_args)
    end
  end
end
