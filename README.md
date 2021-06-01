# Readstat

A CLI app that shows reading statistics based on a CSV reading log.

![Readstat sample video](/sample.gif)

The reading log looks like this:

![Readstat sample CSV reading log](/sample-csv.jpg)

(That is a CSV file viewed in VS Code with the [Rainbow CSV extension](https://marketplace.visualstudio.com/items?itemName=mechatroner.rainbow-csv).)

## Usage

For a sample reading log, see [`read.csv`](https://github.com/fpsvogel/readstat/blob/main/lib/config.rb).

To start the app, download and extract the source code, then run:

    ruby readstat FILEPATH

Where FILEPATH is the path of your CSV log file.

You can also enter your log filepath into `lib/readstat.rb`, then simply run:

    ruby readstat

To run a single command straight from the command line, you can enter it as arguments, e.g.:

    ruby readstat average length

For instructions on commands, enter `help` in the app, or see [`cli.rb`](https://github.com/fpsvogel/readstat/blob/main/lib/cli.rb#L50).

## Contributing

Bug reports are welcome at https://github.com/fpsvogel/readstat/issues.

## License

The app is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
