> [!WARNING]  
> This project is unmaintained, and now replaced by my Reading gem: https://github.com/fpsvogel/reading

<h1 align="center">Readstat</h1>

A CLI app that shows reading statistics based on a CSV reading log.

![Readstat sample video](/sample.gif)

The reading log looks like this:

![Readstat sample CSV reading log](/sample-csv.jpg)

(That is a CSV file viewed in VS Code with the [Rainbow CSV extension](https://marketplace.visualstudio.com/items?itemName=mechatroner.rainbow-csv).)

### Table of Contents
- [Usage](#usage)
- [A flexible command parser](#a-flexible-command-parser)
- [A flexible API](#a-flexible-api)
- [Contributing](#contributing)
- [License](#license)

## Usage

For a sample reading log, see [`reading.csv`](https://github.com/fpsvogel/readstat/blob/main/csv/reading.csv).

To start the app, download the source code, then run:

    $ ruby readstat FILEPATH

Where FILEPATH is the path of your CSV log file.

You can also enter your log filepath into `lib/readstat.rb`, then simply run:

    $ ruby readstat

To run a single command straight from the command line, you can enter it as arguments, e.g.:

    $ ruby readstat average length

For instructions on commands, enter `help` in the app, or see [`cli.rb`](https://github.com/fpsvogel/readstat/blob/main/lib/cli.rb#L50).

## A flexible command parser

CLI queries are responsive to different orderings of the same commands and filters. In other words, you can ask for the same data but nested differently. For example:

- `average amount monthly by genre` will show a breakdown of months, where each month shows a list of amounts read in each genre.
- `average amount by genre monthly` will show a breakdown of genres, where each genre shows of list of amounts read during each month.

The command parser also doesn't care if commands or filters come first, so the first command above could also be entered as `monthly average amount by genre` if you wish.

## A flexible API

Another area of flexibility is [the quasi-DSL](https://github.com/fpsvogel/readstat/blob/main/lib/cli.rb#L48) in which the commands and filters are defined, so that developing more of them is far easier than if they were hardcoded.

## Contributing

Bug reports are welcome at https://github.com/fpsvogel/readstat/issues.

## License

The app is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
