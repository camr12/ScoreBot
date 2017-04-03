require 'discordrb'
require 'json'
require 'tzinfo'
require 'active_support/core_ext/enumerable'
require './modules.rb'


# Discord


bot = Discordrb::Commands::CommandBot.new token: '***REMOVED***', client_id: ***REMOVED***, prefix: '!', help_command: false

bot.bucket :afl, limit: 1, time_span:900

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

bot.command(:afl) do |event, *team|
  newteam = team.join(" ")
  score = Afl.get_id(newteam)
  event.respond "#{score}"
end

bot.command(:a, bucket: :afl) do |event|
  newteam = "Australia"
  score = Cric.cricket_score(newteam)
  event.respond "#{score}"
end

bot.command(:ladder, bucket: :afl) do |event|
file = File.open("./ladder.png")
event.channel.send_file(file)
end

bot.command(:liveladder, bucket: :afl) do |event|
file = File.open("./live.png")
event.channel.send_file(file)
end
bot.command(:emotes, bucket: :afl) do |event|
puts server.emoji.values.find { |e| e.name == v }.to_s] }.to_h 
end
  
bot.run
