# frozen_string_literal: true

module Readstat
  def self.config
    @config
  end

  @config =
  {
    load:
      {
        path:                     nil, # test CSVs are in test/load_items_test.rb
        csv_columns:              %i[rating
                                     name
                                     sources
                                     dates_started
                                     dates_finished
                                     genres
                                     length
                                     notes],
        error_if_blank:           %i[name length],
        header_first:             "Rating",
        comment_mark:             "\\",
        section_mark:             "\\------ ",
        section_prefixes:         { done:     "DONE",
                                    current:  "CURRENT",
                                    will:     "WILL" },
        required_sections:        [:done],
        default_progress:         { done: 100 },
        dnf_mark:                 "DNF",
        separator:                ",",
        column_separator:         "|",
        name_separator:           " - ",
        date_separator:           ".",
        date_added_separator:     ";",
        notes_newline:            " -- "
      },
    item:
      {
        # only template[:perusals] is applied BEFORE warnings are shown for
        # blanks. this means perusals cannot get a blank warning, whereas format
        # (for example) will get a blank warning before the default of :print is
        # applied. see Item::Validate#call.
        template:     { rating: nil,
                        format: :print,
                        author: nil,
                        title: nil,
                        isbn: nil,
                        sources: [["Unspecified"]],
                        perusals: [{ date_added:    nil,
                                     date_started:  nil,
                                     date_finished: nil,
                                     progress: nil }],
                        genres: ["Uncategorized"],
                        length: 0,
                        notes: nil },
        formats:      { print:  "📕",
                        ebook:  "⚡",
                        audio:  "🔊",
                        video:  "🎞️",
                        course: "🏫",
                        pdf:    "📄" },
        length:
          { pages_per_hour: 40 },
        lengths:
          { short: [0, 200],
            medium: [200, 400],
            long: [400, 700],
            huge: [700, Float::INFINITY] },
        sources:
          {
            names_from_urls:      { /youtu\.?be/ => "YouTube",
                                    /books\.google/ => "Google Books",
                                    /archive\.org/ => "Internet Archive",
                                    /lexpublib/ => "Lexington Public Library",
                                    /tv\.apple\.com/ => "Apple TV" }
          },
        validate:
          {
            warn_if_blank:        { [:rating] => "Rating",
                                    [:format] => "Format",
                                    [:isbn, :sources] => "Source (ISBN-10/ASIN or URL)",
                                    [:genres] => "Genre" },
            dont_warn_if_status:  [:current, :will]
          }
      },
    input:
      {
        exit:               %w[exit e quit q !!!]
      },
    output:
      {
        views:              %i[table bar pie raw],
        units:              %i[pages hours],
        appearance:
          {
            pie_fill_chars: %w[▅ ▌],
            pie_radius:     8
          }
      }
  }
end
