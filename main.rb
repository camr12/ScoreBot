require 'discordrb'
require 'json'
require 'tzinfo'
require 'active_support/core_ext/enumerable'
require './modules.rb'


# Discord


bot = Discordrb::Commands::CommandBot.new token: '***REMOVED***', client_id: ***REMOVED***, prefix: '!'

bot.bucket :afl, limit: 1, time_span:1800

bot.command(:cricket, bucket: :afl) do |event, *team|
  newteam = team.join(" ")
  score = Cric.cricket_score(newteam)
  event.respond "#{score}"
end

bot.command(:delete, min_args: 1) do |event, amount|
  channel = event.channel
  number = amount.to_i
  channel.prune(number, false)
end

bot.command(:commands, max_args: 0) do |event|
  event.user.pm "To fetch the score for a match, do '!score <team name>', e.g. '!team Australia'."
end

#bot.command :afl do |event, *team|
#  newteam = team.join(" ")
#  score = Afl.afl_score(newteam)
#  event.respond "#{score}"
#end

bot.command(:afl, bucket: :afl) do |event, *team|
  newteam = team.join(" ")
  score = Afl.get_id(newteam)
  event.respond "#{score}"
end

bot.command(:a, bucket: :afl) do |event|
  newteam = "Australia"
  score = Cric.cricket_score(newteam)
  event.respond "#{score}"
end

bot.run
