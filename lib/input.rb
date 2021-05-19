# frozen_string_literal: true

require_relative "util"
require "readline"

module Readstat
  using Blank

  class Input
    def initialize(config_input)
      @default_input = config_input[:default_input]
      @exit          = config_input[:exit]
    end

    def each_line(&block)
      if ARGV.empty?
        while raw_input = Readline.readline(Colors.bright_cyan("> "), true)
          exit if @exit.include?(raw_input)
          next if raw_input.empty? || raw_input.match?(/\A\s+\z/)
          input = raw_input.presence || @default_input
          block.call(input) # TODO: remove default input
        end
      else
        block.call(ARGV)
      end
    end
  end
end
