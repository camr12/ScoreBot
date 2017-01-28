require 'discordrb'
require 'json'
require 'tzinfo'
require 'active_support/core_ext/enumerable'
require './modules.rb'


# Discord


bot = Discordrb::Commands::CommandBot.new token: '***REMOVED***', client_id: ***REMOVED***, prefix: '!'

bot.command :score do |event, *team|
  newteam = team.join(" ")
  score = Cric.cricket_score(newteam)

  if score.end_with? "."
    event.respond "#{score}"
  elsif score.end_with? ". "
    event.respond "#{score}"
  elsif score.end_with? "    "
    event.respond "#{score}"
  elsif score.end_with? "  "
    event.respond "#{score}"
  else
    rr = runrate(score)
    event.respond "#{score} - #{rr} RPO"
  end
end

bot.command(:delete, min_args: 1) do |event, amount|
  channel = event.channel
  number = amount.to_i
  channel.prune(number, false)
end

bot.command(:commands, max_args: 0) do |event|
  event.user.pm "To fetch the score for a match, do '!score <team name>', e.g. '!team Australia'."
end



bot.command(:clear, min_args: 1)

# bot.command(:invite, chain_usable: false) do |event|
#  event.bot.invite_url
# end

bot.run
