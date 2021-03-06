# frozen_string_literal: true

require_relative "util"
require "readline"

module Reading
  using Blank

  # Input is a function that reads each line of input from the CLI.
  class Input
    def initialize(config_input)
      @exit = config_input[:exit]
    end

    def each_line(&block)
      if ARGV.empty?
        while raw_input = Readline.readline(Colors.bright_cyan("> "), true)
          exit if @exit.include?(raw_input)
          next if raw_input.empty? || raw_input.match?(/\A\s+\z/)
          input = raw_input.presence
          block.call(input)
        end
      else
        block.call(ARGV)
      end
    end
  end
end
