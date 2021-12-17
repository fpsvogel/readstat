# frozen_string_literal: true

require_relative "../util"

module Reading
  # a Help is a standin for a Command, sharing the same interface for outputting.
  class Help
    attr_private :help_str

    def initialize(all_commands, all_filters, all_options, examples_and_comments)
      @help_str = "#{examples(examples_and_comments)}\n\n" \
                  "#{commands_help(all_commands)}\n\n" \
                  "#{filters_help(all_filters)}\n\n" \
                  "#{options_help(all_options)}\n\n"
    end

    def examples(examples_and_comments)
      Colors.underline("EXAMPLES") + "\n" +
      examples_and_comments.map do |example, comment|
        "#{Colors.bright_cyan(example)}\n    #{Colors.green(comment)}\n"
      end.join("\n")
    end

    def commands_help(all_commands)
      Colors.underline("COMMANDS") + "\n" +
        all_commands.map do |key, cmd|
          "#{Colors.blue.bold(cmd.name)} " \
            "#{Colors.green("[#] ") if cmd.takes_number_arg}" \
            "#{Colors.bright_red(cmd.all_args.join("/"))}: " \
            "#{cmd.description}"
        end.join("\n")
    end

    def filters_help(all_filters)
      Colors.underline("FILTERS") + "\n" +
        all_filters.map do |key, filter|
          "#{Colors.blue.bold(filter.description[0])}: " \
            "#{filter.description[1]}"
        end.join("\n")
    end

    def options_help(all_options)
      Colors.underline("OPTIONS") + "\n" +
        all_options.map do |key, option|
          "#{Colors.blue.bold(option.description[0])}: " \
            "#{option.description[1]}"
        end.join("\n")
    end

    def result(*args)
      self
    end

    def output(*args)
      puts "\n#{help_str}"
    end
  end
end
