require 'json'
require 'tzinfo'
require 'active_support/core_ext/enumerable'
require 'pp'
require 'time'
require 'uri'
require 'net/http'
require 'nokogiri'
require 'open-uri'
require 'discordrb'
require 'yaml'

$secure = YAML.load_file('secure.yaml')
$emotes = YAML.load_file("emotes.yml")

def in_progress_games # Get all in progress games, print on newlines
  games = open("http://dtlive.com.au/afl/viewgames.php").read
  in_progress = games.scan(/GameID=(\d+)">[^>]+>\s+(?:([A-Za-z ]+[^<]+)\s+vs[^>]+>\s*([^>]+)|([^>]+)\s+vs[^>]+>\s*([A-Za-z ]+[^<]+))\s+\(in progress\)</)
  if in_progress.empty? # If games are on
    result = "Sorry, no games are on! <:vicbias:275912832992804865>"
    puts result
    return result
  else
    in_progress.map! { |inner| inner[0] } #get only IDs
    gametracker = []
    numerical = 0
    teams = {"Adelaide"=>"<:crows:240102697196453888>",
             "Brisbane"=>"<:lions:240107932836954115>",
             "Carlton"=>"<:blues:240110286705524737>",
             "Collingwood"=>"<:pies:240111431226359809>",
             "Essendon"=>"<:dons:240112429344751616>",
             "Geelong"=>"<:cats:240116808634335234>",
             "GWS Giants"=>"<:gws:240123319104438273>",
             "Hawthorn"=>"<:hawks:246532872217952266>",
             "Melbourne"=>"<:dees:246534269931880449>",
             "St Kilda"=>"<:saints:246535544106909697>",
             "Bulldogs"=>"<:dogs:246535548766912512>",
             "North Melbourne"=>"<:norf:246535714299314187>",
             "Port Adelaide"=>"<:port:246536450399666186>",
             "Sydney"=>"<:swans:246537524422377472>",
             "Western Bulldogs"=>"<:dogs:246535548766912512>",
             "Richmond"=>"<:tigers:246537629225582592>",
             "Gold Coast"=>"<:suns:246541592612175872>",
             "Fremantle"=>"<:freo:248060573512761346>",
             "West Coast"=>"<:eagles:297781448507785216>"}

    in_progress.each do |gameid|
      numerical += 1
      data = {:id => gameid}
      data[:number] = numerical
      feed = open("http://dtlive.com.au/afl/xml/#{gameid}.xml").read
      feed = Nokogiri::XML(feed)
      feed.css('Game').each do |node|
        children = node.children
        children.each do |item|
          case item.name
          when "Location"
            data[:location] = item.inner_html
          when "CurrentQuarter"
            data[:current_qtr] = item.inner_html
          when "HomeTeam"
            data[:home_team] = item.inner_html
          when "HomeTeamShort"
            data[:home_team_short] = item.inner_html
          when "AwayTeam"
            data[:away_team] = item.inner_html
          when "AwayTeamShort"
            data[:away_team_short] = item.inner_html

          when "CurrentTime"
            data[:current_time] = item.inner_html
          when "PercComplete"
            data[:perc_complete] = item.inner_html.to_i
          when "HomeTeamGoal"
            data[:home_goals] = item.inner_html
          when "HomeTeamBehind"
            data[:home_points] = item.inner_html
          when "AwayTeamGoal"
            data[:away_goals] = item.inner_html
          when "AwayTeamBehind"
            data[:away_points] = item.inner_html
          end
        end
      end

      data[:home_total] = data[:home_goals].to_i * 6 + data[:home_points].to_i
      data[:away_total] = data[:away_goals].to_i * 6 + data[:away_points].to_i

      gametracker << data
    end

    result = ""
    gametracker.each do |gamehash| # For each

      if gamehash[:home_total].to_i > gamehash[:away_total].to_i
        gamehash[:margin] = gamehash[:home_total].to_i - gamehash[:away_total].to_i
        gamehash[:finalmargin] = "*#{gamehash[:home_team_short]} by #{gamehash[:margin]}*"
      elsif gamehash[:away_total].to_i > gamehash[:home_total].to_i
        gamehash[:margin] = gamehash[:away_total].to_i - gamehash[:home_total].to_i
        gamehash[:finalmargin] = "*#{gamehash[:away_team_short]} by #{gamehash[:margin]}*"
      elsif gamehash[:away_total].to_i == gamehash[:home_total].to_i
        gamehash[:margin] = "0"
        result[:finalmargin] = "Scores level."
      elsif gamehash[:home_total].to_i == gamehash[:away_total].to_i
        gamehash[:margin] = "0"
        result[:finalmargin] = "Scores level."
      end

      result += "**#{gamehash[:home_team]}** vs **#{gamehash[:away_team]}** at #{gamehash[:location]} - Q#{gamehash[:current_qtr]} - #{teams[gamehash[:home_team]]} #{gamehash[:home_goals]}.#{gamehash[:home_points]}.#{gamehash[:home_total]} - #{teams[gamehash[:away_team]]} #{gamehash[:away_goals]}.#{gamehash[:away_points]}.#{gamehash[:away_total]} - #{gamehash[:finalmargin]}\n"
    end
    puts result
    return result
  end
end

in_progress_games()
