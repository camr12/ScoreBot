ScoreBot is a **Discordrb** bot that provides a way for users of a Discord server to check live AFL and cricket scores. It can also fetch a live ladder of the AFL season.

To install, clone the repo and get an API key from [Cric API](http://www.cricapi.com/). You'll also need a client ID for Discord as well as a Discord token. These need to go in a file called *secure.yaml*, which will not be pushed to GitHub. Here's the syntax for the file:

```
cric_api_key: <cric_api_key>
token: <discord_token>
client_id: <discord_client_id>
```

To run, run *main.rb* with **Discordrb** and the other dependencies installed via gem or bundler.

```
bundle exec ruby main.rb
```

List of files and what they do:

* *main.rb* - contains the **Discordrb** commands, uses modules.rb

* *modules.rb* - backbone of the bot, has two modules, Cric and AFL

* *live.rb* - fetches an AFL live ladder

* *ladder.rb* - fetches an official AFL ladder

* *Gemfile* - list of dependencies through gem

* *secure.YAML* - needed to store API keys
