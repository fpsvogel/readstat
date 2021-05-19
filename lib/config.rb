# frozen_string_literal: true

module Readstat
  def self.config
    @config
  end

  @config =
  {
    load:
      {
        path:                     '/mnt/c/Users/User1/Dropbox/Apps/SimpleText/read.csv',
        csv_columns:              %i[rating
                                     name
                                     sources
                                     dates_started
                                     dates_finished
                                     genres
                                     length
                                     notes],
        header_first:             "Rating",
        comment_mark:             "\\",
        section_mark:             "\\------ ",
        # TODO: raise error if any labels conflict (if one starts with another) in LoadLibrary#update_section
        section_prefixes:         { done:     "DONE",
                                    current:  "CURRENT",
                                    will:     "WILL" },
        required_sections:        [:done],
        default_progress:         { done: 100 }, # others get 0
        dnf_mark:                 "DNF",
        separator:                ",", # TODO: must be a single character
        column_separator:         "|", # TODO: must be a single character
        name_separator:           " - ",
        date_separator:           ".", # TODO: must be a single character
        date_added_separator:     ";", # TODO: must be a single character
        notes_newline:            " -- "
      },
    item:
      {
      template:       { rating: nil,
                        format: :print,
                        author: nil,
                        title: nil,
                        isbn: nil,
                        sources: [],
                        perusals: [{ date_added:    nil,
                                     date_started:  nil,
                                     date_finished: nil,
                                     progress: nil }],
                        genres: [],
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
                                    [:isbn, :sources] => "Source (ISBN-10/ASIN or URL)" },
                                    #[:perusals] => "Date(s) Added/Started/Finished" }, # TODO: how to warn of this?
                                    #[:dates_started] => "Date(s) Started",
                                    #[:dates_finished] => "Date(s) Finished" },
            dont_warn_if_status:  [:current, :will]
          }
      },
    input:
      {
        default_input:      "a l monthly genrely",
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
