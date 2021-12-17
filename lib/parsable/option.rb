# frozen_string_literal: true

require_relative "parsable"

module Reading

  # an Option is any non-command entered in the CLI, such as "view=pie".
  class Option < Parsable
    attr_reader :description
    private_class_method :new

    def initialize(name, description, regex = nil,
                   plural_ending: "s", default: nil)
      @name = name.to_sym
      @description = description
      @regex = regex || default_regex(plural_ending)
      @default = default
      @not_mode = false
      @not_mode_possible = false
      @has_single_value = true
    end

    protected

    def default_regex(plural_ending)
      /#{name}(?:#{plural_ending})?!=(?<not>.+)|#{name}(?:#{plural_ending})?=(?<is>.+)/
    end
  end
end
