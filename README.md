ScoreBot is a **discordrb** bot that provides a way for users of a Discord server to check live AFL and cricket scores. It can also fetch a live ladder of the AFL season.

To run, run *main.rb* with **discordrb** and the other dependencies installed via gem or bundler.

List of files and what they do:

* *main.rb* - contains the **discordrb** commands, uses modules.rb

* *modules.rb* - backbone of the bot, has two modules, Cric and AFL

* *live.rb* - fetches an AFL live ladder

* *ladder.rb* - fetches an official AFL ladder

* *Gemfile* - list of dependencies through gem