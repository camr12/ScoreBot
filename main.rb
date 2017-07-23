require 'discordrb'
require 'json'
require 'tzinfo'
require 'active_support/core_ext/enumerable'
require './modules.rb'

$secure = YAML.load_file('secure.yaml')

# Discord

token = $secure["token"]
client_id = $secure["client_id"]

bot = Discordrb::Commands::CommandBot.new token: token, client_id: client_id, prefix: '!', help_command: false

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
  event.user.pm "To fetch the score for a match, do '!score <team name>',
                 e.g. '!team Australia'."
end

#bot.command :afl do |event, *team|
#  newteam = team.join(" ")
#  score = Afl.afl_score(newteam)
#  event.respond "#{score}"
#end
bot.command(:now) do |event|
result = Afl.in_progress_games
event.respond "#{result}"
end
bot.command(:afl) do |event, *team|
   zedteams = {"Adelaide" => ["adelaide", "crows", "ade", "adel"],
                "Brisbane" => ["brisbane", "lions", "bl", "bris", "fitzroy", "bears"],
                "Carlton" => ["carlton", "blues", "car", "carl"],
                "Collingwood" => ["collingwood", "magpies", "pies", "col",
                                                                    "coll"],
                "Essendon" => ["essendon", "bombers", "ess"],
                "Fremantle" => ["fremantle", "dockers", "fre", "freo"],
                "Geelong" => ["geelong", "cats", "gee", "geel"],
                "Gold Coast" => ["gold coast", "suns", "gc", "gcfc"],
                "GWS Giants" => ["greater western sydney", "giants", "gws"],
                "Hawthorn" => ["hawthorn", "hawks", "haw", "hawtron"],
                "Melbourne" => ["melbourne", "demons", "dees", "mel", "melb"],
                "North Melbourne" => ["north melbourne", "kangaroos", "roos",
                                      "nmfc", "norf", "north"],
                "Port Adelaide" => ["port adelaide", "power", "port", "pa",
                                                              "pafc", "pear"],
                "Richmond" => ["richmond", "tigers", "rich", "tiges",
                                                             "ninthmond"],
                "St Kilda" => ["st kilda", "saints", "stk", "street kilda",
                                                            "satin kilda"],
                "Sydney" => ["sydney", "swans", "syd", "south melbourne",
                                                      "smfc", "bloods"],
                "West Coast" => ["west coast", "eagles", "wce", "wc",
                                                         "weagles"],
                "Western Bulldogs" => ["western bulldogs", "bulldogs", "dogs",
                                                           "wb", "footscray"]}
  newteam = team.join(" ").downcase
  unless zedteams.values.flatten.include?(newteam)
    bot.send_temporary_message(event.channel.id, content = "
    #{event.author.mention}: \<:bt:246541254182174720> THAT WAS OUT OF BOUNDS!
    `#{newteam}` is not an accepted input!", timeout = 10)
    sleep 10
    event.message.delete
    raise ArgumentError.new("THAT WAS OUT OF BOUNDS!")
  end
  score = Afl.process_feed(newteam)
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

bot.command(:topten) do |event, *team|
  team = team.join(" ").downcase # make downcase
  team = team.split(/ |\_|\-/).map(&:capitalize).join(" ") # make sentence case
  event.respond Stats.get_top_ten(Stats.get_gameid(team)[:gameid])
end

bot.run
