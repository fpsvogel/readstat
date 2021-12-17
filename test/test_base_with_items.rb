$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require_relative "test_base"
require "item/item"
require "cli"
require "parsable/command"
require "library/library"

class ReadingTest < Minitest::Test
  self.class.attr_reader :all_items, :config, :err_block, :err_log

  def self.clear_err_log
    @err_log = []
  end

  def config
    self.class.config
  end

  def err_block
    self.class.err_block
  end

  def err_log
    self.class.err_log
  end
end

class ReadingTestWithItems < ReadingTest
  def self.all_items
    @all_items ||=
      {
        booklet: Reading::Item.create(
          { rating: 3,
            format: :ebook,
            author: "Ernest Hemingway",
            title: "The Old Man and the Sea",
            isbn: "B08VLX7ZW2",
            perusals: [{ date_added:     "2020-12-20",
                         date_started:   "2020-12-31",
                         date_finished:  "2021-01-01" }],
            genres: ["fiction"],
            length: 128 },
          config.fetch(:item)
        ),
        prequel: Reading::Item.create(
          { rating: 5,
            format: :print,
            author: "J. R. R. Tolkien",
            title: "The Hobbit",
            isbn: "0007440847",
            sources: ["Lexington Public Library"],
            perusals: [{ date_started:   "2021-01-02",
                         date_finished:  "2021-01-12" },
                       { date_started:   "2020-10-24",
                         date_finished:  "2020-10-31" }],
            genres: ["fiction"],
            length: 300 },
          config.fetch(:item)
        ),
        podcast: Reading::Item.create(
          { rating: 4,
            format: :audio,
            author: nil,
            title: "Radiolab, Season 11",
            isbn: nil,
            sources: ["https://www.wnycstudios.org/podcasts/radiolab"],
            perusals: [{ date_started:   "2021-01-10",
                         date_finished:  "2021-01-31" }],
            genres: ["podcast", "science"],
            length: "8:30" },
          config.fetch(:item)
        ),
        docu: Reading::Item.create(
          { rating: 4,
            format: :video,
            author: nil,
            title: "Planet Earth",
            isbn: nil,
            sources: ["DVD",
                      "https://www.bbc.co.uk/programmes/b006mywy"],
            perusals: [{ date_started:   "2021-01-31",
                         date_finished:  "2021-02-17" }],
            genres: ["nature show", "science"],
            length: "9:00" },
          config.fetch(:item)
        ),
        movie: Reading::Item.create(
          { rating: 3,
            format: :video,
            author: nil,
            title: "Chasing Coral",
            isbn: nil,
            sources: ["Netflix",
                      "https://www.chasingcoral.com"],
            perusals: [{ date_started:   "2021-02-28",
                         date_finished:  "2021-02-28" }],
            genres: ["science", "nature show"],
            length: "1:30" },
          config.fetch(:item)
        ),
        tome: Reading::Item.create(
          { rating: 1,
            format: :print,
            author: "Samuel Richardson",
            title: "Pamela: Or Virtue Rewarded",
            isbn: "0192829602",
            sources: ["Lexington Public Library"],
            perusals: [{ date_added:     "2021-01-01",
                         date_started:   "2021-01-13",
                         date_finished:  "2021-03-01",
                         progress:       50 }],
            genres: ["fiction"],
            length: 592 },
          config.fetch(:item)
        ),
        novel: Reading::Item.create(
          { rating: 4,
            format: :audio,
            author: "J. R. R. Tolkien",
            title: "The Fellowship of the Ring",
            isbn: "B007978NPG",
            sources: ["Libro FM"],
            perusals: [{ date_started:   "2015-11-01",
                         date_finished:  "2015-12-20" },
                       { date_started:   "2021-01-19" }],
            genres: ["fiction"],
            length: "19:06" },
          config.fetch(:item)
        ),
        course: Reading::Item.create(
          { rating: nil,
            format: :course,
            author: nil,
            title: "Khan Academy - Algebra 2",
            isbn: nil,
            sources: [["Khan Academy", "https://www.khanacademy.org/math/algebra2"]],
            perusals: [{ date_started: "2021-03-25" }],
            genres: ["math"],
            length: "6:00" },
          config.fetch(:item)
        ),
        to_watch: Reading::Item.create(
          { rating: nil,
            format: :video,
            author: nil,
            title: "Planet Earth II",
            isbn: nil,
            sources: ["DVD",
                      "https://www.bbc.co.uk/programmes/p02544td"],
            perusals: [{ date_added: "2021-02-17" }],
            genres: ["science", "nature show"],
            length: "5:00" },
          config.fetch(:item)
        )
      }
  end

  def all_items
    self.class.all_items
  end

  def basic_items_keys
    %i[booklet prequel podcast docu movie tome novel course to_watch]
  end

  def basic_items
    all_items.slice(*basic_items_keys)
  end

  def basic_done_dnf_items
    Reading::Library.sort(items_split(*basic_items_keys).select { |item| [:done, :dnf].include?(item.status) })
  end

  def items(*keys)
    all_items.slice(*keys).values
  end

  def items_split(*keys)
    all_items.slice(*keys).values.flat_map(&:split_rereads)
  end

  def titles(*keys)
    keys.map { |key| all_items[key].title }
  end
end