# frozen_string_literal: true

require_relative "util"
require_relative "errors"
require "tabulo"
require "unicode_plot"
require "tty-pie"

# TODO: do not modify @raw

module Readstat
  class Result
    using HashToAttr
    attr_reader :raw
    attr_private :cmd, :view, :unit

    def initialize(raw_result, command)
      @raw = raw_result
      @cmd = command
      @view = cmd.output_options[:view]&.value&.to_sym || :raw
      @unit = cmd.output_options[:unit]&.value&.to_sym
      pluralize_unit
    end

    def pluralize_unit
      return if unit.nil?
      @unit = "#{@unit}s" unless @unit.to_s.chars.last == "s"
    end

    def table_styles
      @table_styles ||= [Colors.bright_red.detach,
                         Colors.bright_blue.bold.detach,
                         Colors.bright_yellow.detach,
                         Colors.magenta.detach,
                         Colors.bright_green.detach]
    end

    def output(config_output)
      if numeric_view? && !numeric_data?
        raise OutputError, "Cannot show non-numeric data in a numeric view ."
      end
      config_output.fetch(:appearance).to_attr_private(self)
      convert_by_unit
      if view == :raw
        print_raw
      else
        send("output_depth_#{depth}")
      end
    end

    protected

    def convert_by_unit
      return if unit.nil?
      @raw = convert(raw, "with_#{unit}_output")
    end

    def numeric_view?
      view != :table
    end

    def numeric_data?
      cmd.name != :list
    end

    def title(extra: nil)
      prefix = "#{extra} — " unless extra.nil?
      "#{prefix}#{cmd.name} #{cmd.arg}#{unit_postfix}"
    end

    def unit_postfix
      return "" unless include_unit_in_title?
      " (#{unit || "pages"}#{" per day" if cmd.wrap_per_day})"
    end

    def include_unit_in_title?
      view != :table
    end

    def section_superheading(name)
      lines = ["╓─────#{"─" * (name.to_s.length + superheading_extra)}─────╖",
               "║     #{name}   #{" " * superheading_extra}  ║",
               "╙─────#{"─" * (name.to_s.length + superheading_extra)}─────╜"]
      puts ""
      lines.each do |line|
        yield line
      end
    end

    def superheading_extra
      80
    end

    def section_heading(name)
      "\n╓─────#{"─" * name.to_s.length}─────╖" +
      "\n╠══   #{name}   ══╣" +
      "\n╙─────#{"─" * name.to_s.length}─────╜"
    end

    def section_subheading(name)
      "╒══   #{name}   ══╕"
    end

    def output_depth_1
      puts Colors.bright_blue.bold(raw) + "\n"
    end

    def output_depth_2(result_hash = raw, group = nil)
      send("print_#{view}", result_hash, title_extra: group)
    end

    def output_depth_3(result_hash = raw)
      result_hash.each do |group, result|
        output_depth_2(result, group)
      end
    end

    def output_depth_4(result_hash = raw)
      result_hash.each do |group, result|
        puts Colors.bright_magenta.bold(section_heading(group))
        output_depth_3(result)
      end
    end

    def output_depth_5(result_hash = raw)
      result_hash.each do |group, result|
        section_superheading(group) { |line| puts Colors.black.on_white.bold(line) }
        output_depth_4(result)
        puts ""
      end
    end

    def print_table(results, title_extra: nil)
      if data_multicolumns(results)
        puts Colors.cyan.bold(section_subheading(title_extra))
      end
      table = Tabulo::Table.new(values_to_s(results),
                                column_padding: [1, 4],
                                border: :modern) do |t|
        (1..(data_multicolumns(results) || 2)).each do |col|
          header, data, style = column_content(col, results, title_extra)
          t.add_column(header,
                       align_header: :left,
                       header_styler: -> (s) { Colors.bright_white.bold(s) },
                       styler: -> (_cell_value, s) { style.call(s) },
                       &data)
        end
      end
      table.pack
      puts table
    end

    def data_multicolumns(results)
      return results.first.count if results.is_a? Array
      nil
    end

    def column_content(col, results, title_extra)
      if data_multicolumns(results).nil?
        if col == 1
          header = title_extra
          data = :first.to_proc
        elsif col == 2
          header = title
          data = :last.to_proc
        end
      else
        header = results.first.keys[col - 1]
        data = ->(columns) { columns.to_a[col - 1].last }
      end
      [header, data, table_styles[col - 1]]
    end

    def print_bar(result_hash, title_extra: nil)
      UnicodePlot.barplot(data: values_to_f(result_hash), title: title(extra: title_extra))
                 .render
    end

    def print_pie(result_hash, title_extra: nil)
      colors = %i[red green yellow blue magenta cyan white]
      colors_all = colors.map { |color| "bright_#{color}".to_sym } + colors
      fills_all = pie_fill_chars * (colors_all.count.to_f / pie_fill_chars.count).ceil
      data = values_to_f(result_hash).map.with_index do |(k, v), i|
        { name: k, value: v, color: colors_all[i], fill: fills_all[i] }
      end
      pie_chart = TTY::Pie.new(data: data, radius: pie_radius)
      left_spaces = " " * (pie_radius * 2 - (title(extra: title_extra).length / 2))
      puts(Colors.bright_white.bold("\n #{left_spaces}#{title(extra: title_extra)}\n"))
      puts pie_chart
    end

    def print_raw
      pp raw
    end

    def depth(obj = raw)
      if obj.is_a? Hash
        1 + depth(obj.values.first)
      elsif obj.is_a? Array
        depth(obj.first)
      else
        1
      end
    end

    def values_to_f(results)
      convert(results, :to_f) { |float| float.to_i == float ? float.to_i : float }
    end

    def values_to_s(results)
      convert(results, :to_s)
    end

    # def with_any_values(hash)
    #   convert(hash, :float_or_string)
    # end

    # def float_or_string(v)
    #   Float(v, exception: false) || String(v)
    # end

    def convert(results, target, &postconversion)
      if results.is_a? Hash
        convert_hash(results, target, &postconversion)
      elsif results.is_a? Array
        results.map { |row| convert_hash(row, target, &postconversion) }
      end
    end

    def convert_hash(hash, target, &postconversion)
      hash.transform_values do |v|
        converted = v.send(target) if v.respond_to?(target)
        converted = v if converted.nil?
        postconversion&.call(converted) || converted
      rescue ArgumentError
        return nil
      end
    end

    # def table
    #   tab = Tabulo::Table.new([1, 2, 5]) do |t|
    #     t.add_column(:itself)
    #     t.add_column(:even?,
    #       styler: -> (cell_value, s) { cell_value ? Colors.green(s) : Colors.red(s) })
    #     t.add_column(:odd?)
    #   end
    #   puts tab
    # end
  end
end
