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

# Module for checking cricket scores/schedules using the CricAPI
module Cric
  $cric_api_key = $secure["cric_api_key"]
  # convert GMT time to timezone defined by tz variable
  def self.gmttime(tstr)
    # timezone to convert to
    tz = TZInfo::Timezone.get('Australia/Sydney')
    # parse time
    time = Time.parse(tstr)
    # convert to "hour:second AM/PM" and timezone
    tz.utc_to_local(time).strftime("%I:%M %p")
  end

  def self.gmtdate(tstr)
    # timezone to convert to
    tz = TZInfo::Timezone.get('Australia/Sydney')
    # parse time
    time = Time.parse(tstr)
    # convert to "hour:second AM/PM" and timezone
    tz.utc_to_local(time).strftime("%B %d, %Y")
  end

  def self.fetch_matchescric
    # fetch json for match list
    uri = URI("http://cricapi.com/api/matches/?apikey=#{$cric_api_key}")
    # parse match list as hash
    JSON.parse(Net::HTTP.get(uri))['matches']
  end

  def self.fetch_scorecric(id)
    uri = URI("http://cricapi.com/api/cricketScore?apikey=#{$cric_api_key}&unique_id=#{id}") # fetch json for matchs core
    JSON.parse(Net::HTTP.get(uri)) # parse score list as hash
  end

  def self.cricket_score(team)
    id = fetch_matchescric.find { |h| h.key(team) }['unique_id']

    score = fetch_scorecric(id)
    result = {}

    if score.key?('score') && ['score'].include?('Match')
      result[:final] = score['innings-requirement'] << '    '
      result[:final]
    elsif score['innings-requirement'].include?('scheduled') && score['team-2'].include?(team)
      result[:schedule] = score['innings-requirement']
      result[:team] = score['team-1']
      result[:time] = gmttime(score['dateTimeGMT'])
      result[:date] = gmtdate(score['dateTimeGMT'])
      result[:schedule].gsub!(/at\s(.*?\stime)/, "at #{result[:time]} Sydney time (\\1)")
      result[:schedule].gsub!(/\(\d\d:\d\d GMT\)/, "")
      result[:final] = "#{result[:schedule]}against #{result[:team]} on #{result[:date]}." << ' '
      result[:final]
    elsif score['innings-requirement'].include?('scheduled') && score['team-1'].include?(team)
      result[:schedule] = score['innings-requirement']
      result[:team] = score['team-2']
      result[:time] = gmttime(score['dateTimeGMT'])
      result[:date] = gmtdate(score['dateTimeGMT'])
      result[:schedule].gsub!(/at\s(.*?\stime)/, "at #{result[:time]} Sydney time (\\1)")
      result[:schedule].gsub!(/\(\d\d:\d\d GMT\)/, "")
      result[:final] = "#{result[:schedule]}against #{result[:team]} on #{result[:date]}." << ' '
      result[:final]
    elsif score['matchStarted'] == true && score['innings-requirement'].include?('toss') && !score.key?('score')
      result[:toss] = score['innings-requirement']
      result[:final] = "#{result[:toss]}"
    elsif score['matchStarted'] == true && !score['innings-requirement'].include?('toss') && !score['innings-requirement'].include?('won')
      tz = TZInfo::Timezone.get('Australia/Sydney')
      score_dirty = score['score']
      rr = Cric.runrate(score_dirty)
      score_clean = score_dirty.sub(/^([\w ]+) (\d+)\/(\d+)/, '\1 \3/\2')
      required = score['innings-requirement']
      published = Time.parse(score['provider']['pubDate'])
      pub_date1 = tz.utc_to_local(published)
      pub_date2 = pub_date1.strftime('%I:%M %p')
      result[:final] = "#{score_clean} - #{rr} RPO. Updated at #{pub_date2}. \n \n#{required}"
      result[:final]
    elsif score['matchStarted'] == true && !score['innings-requirement'].include?('toss') && score['innings-requirement'].include?('won')
      result[:date] = gmtdate(score['dateTimeGMT'])
      result[:scorecard] = "<http://www.espncricinfo.com/ci/engine/match/#{id}.html>"
      result[:final] = "#{score['innings-requirement']} on #{result[:date]}.\nLink to scorecard: #{result[:scorecard]}"
      result[:final]
    elsif score['matchStarted'] == true
      tz = TZInfo::Timezone.get('Australia/Sydney')
      score_dirty = score['score']
      published = Time.parse(score['provider']['pubDate'])
      pub_date1 = tz.utc_to_local(published)
      pub_date2 = pub_date1.strftime('%I:%M %p')
      rr = runrate(score_dirty)
      score_clean = score_dirty.sub(/^([\w ]+) (\d+)\/(\d+)/, '\1 \3/\2')
      result[:final] = "#{score_clean} - #{rr} RPO. Updated at #{pub_date2}."
      result[:final]
    end
  end

  def self.runrate(score)
    overs = /\(([0-9]+)\.([0-9]+)?/.match(score)[1]
    runs = match_groups = /(\d+)\/(\d+)/.match(score)[1]
    balls = /\(([0-9]+)\.([0-9]+)?/.match(score)[2]
    rate1 = runs.to_f * 6 / ((overs.to_f * 6) + balls.to_f)
    rate2 = '%.2f' % rate1
  end
end

# Module for checking live AFL scores and past games
module Afl

  $token = $secure["token"]
  $client_id = $secure["client_id"]
  def self.get_id(team) # Get the match ID for a team.
    bot = Discordrb::Commands::CommandBot.new token: $token, client_id: $client_id, prefix: '!', help_command: false
    ## Start ZedFish's Code Block

    zedteams = {"Adelaide" => ["adelaide", "crows", "ade", "adel"], # Update for main.rb as well!
                "Brisbane" => ["brisbane", "lions", "bl", "bris", "fitzroy", "bears"],
                "Carlton" => ["carlton", "blues", "car", "carl"],
                "Collingwood" => ["collingwood", "magpies", "pies", "col", "coll"],
                "Essendon" => ["essendon", "bombers", "ess", "dons"],
                "Fremantle" => ["fremantle", "dockers", "fre", "freo"],
                "Geelong" => ["geelong", "cats", "gee", "geel"],
                "Gold Coast" => ["gold coast", "suns", "gc", "gcfc"],
                "GWS Giants" => ["greater western sydney", "giants", "gws"],
                "Hawthorn" => ["hawthorn", "hawks", "haw", "hawtron"],
                "Melbourne" => ["melbourne", "demons", "dees", "mel", "melb"],
                "North Melbourne" => ["north melbourne", "kangaroos", "roos", "nmfc", "norf", "north"],
                "Port Adelaide" => ["port adelaide", "power", "port", "pa", "pafc", "pear"],
                "Richmond" => ["richmond", "tigers", "rich", "tiges", "ninthmond"],
                "St Kilda" => ["st kilda", "saints", "stk", "street kilda", "satin kilda"],
                "Sydney" => ["sydney", "swans", "syd", "south melbourne", "smfc", "bloods"],
                "West Coast" => ["west coast", "eagles", "wce", "wc", "weagles"],
                "Western Bulldogs" => ["western bulldogs", "bulldogs", "dogs", "wb", "footscray"]}

    newteam = team.downcase

    zedteams.each do |key, array|
      if array.include?(newteam)
        team = key
      end
    end

    ## End ZedFish's Code Block
    games = open("http://dtlive.com.au/afl/viewgames.php").read
    in_progress = games.scan(/GameID=(\d+)">[^>]+>\s+(?:([A-Za-z ]+[^<]+)\s+vs[^>]+>\s*([^>]+)|([^>]+)\s+vs[^>]+>\s*([A-Za-z ]+[^<]+))\s+\(in progress\)</)
    completed = games.scan(/GameID=(\d+)">[^>]+>\s+(?:([A-Za-z ]+[^<]+)\s+vs[^>]+>\s*([^>]+)|([^>]+)\s+vs[^>]+>\s*([A-Za-z ]+[^<]+))<small>\(completed\)<\/small></)
    #gameid = games.match(/GameID=(\d+)">[^>]+>\s+(?:(#{team})\s+vs[^>]+>\s*([^>]+)|([^>]+)\s+vs[^>]+>\s*(#{team}))\s+/)[1]

    if in_progress.flatten.include?(team)
      gameid = in_progress.find { |a| a.include? team }.first
    elsif completed.flatten.include?(team)
      completed_ordered_whitespace = completed.sort_by { |number,| number.to_i }.reverse # sort completed matches by ID sequential order
      completed_ordered_whitespace.each &:compact! # remove nil elements
      completed_ordered_no_whitespace = completed_ordered_whitespace.collect{ |arr| arr.collect{|x| x.strip } } # remove whitespace
      gameid_i = completed_ordered_no_whitespace.find { |a| a.include? team }.first # find user team
      gameid = gameid_i.to_s # convert back to string
    end
  end

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

  def self.process_feed(team) # Process a feed into hashes given a team.
    gameid = get_id(team)
    data = {}
    result = {}
    feed = open("http://dtlive.com.au/afl/xml/#{gameid}.xml").read
    feed = Nokogiri::XML(feed)


    data[:home_total] = data[:home_goals].to_i * 6 + data[:home_points].to_i
    data[:away_total] = data[:away_goals].to_i * 6 + data[:away_points].to_i

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

    #result[:final1] = "#{data[:home_team]} vs #{data[:away_team]} at #{data[:location]} - #{data[:perc_complete] == 100 ? "Game finished" : "Game time: #{data[:current_time]} in Q#{data[:current_qtr]}"}"
    #result[:final2] = data[:home_total] > data[:away_total] ? "#{data[:home_team]} #{data[:perc_complete] == 100 ? "won" : "currently winning"} by #{(data[:home_total].to_i-data[:away_total].to_i)} points" : "#{data[:away_team]} #{data[:perc_complete] == 100 ? "won" : "currently winning"} by #{(data[:away_total].to_i-data[:home_total].to_i)} points"
    #result[:final3] = "#{data[:home_team]} - Goals: (#{data[:home_goals]}) Behinds: (#{data[:home_points]}) Total: (#{data[:home_total]}) *vs* #{data[:away_team]} - Goals: (#{data[:away_goals]}) Behinds: (#{data[:away_points]}) Total: (#{data[:away_total]})"

    #result[:final] = "#{result[:final1]} \n#{result[:final2]} \n#{result[:final3]}"

    result[:final1] = "**#{data[:home_team]}** vs **#{data[:away_team]}** at #{data[:location]} - #{data[:perc_complete] == 100 ? "Game finished" : data[:perc_complete] == 25 ? "End of Q#{data[:current_qtr]}" : data[:perc_complete] == 50 ? "End of Q#{data[:current_qtr]}" : data[:perc_complete] == 75 ? "End of Q#{data[:current_qtr]}" : "Game time: #{data[:current_time]} in Q#{data[:current_qtr]}"}"

    result[:final2] = "#{teams[data[:home_team]]} #{data[:home_goals]}.#{data[:home_points]}.#{data[:home_total]} - #{teams[data[:away_team]]} #{data[:away_goals]}.#{data[:away_points]}.#{data[:away_total]}"

    if data[:home_total].to_i > data[:away_total].to_i
      data[:margin] = data[:home_total].to_i - data[:away_total].to_i
      result[:final3] = "*#{data[:home_team_short]} by #{data[:margin]}*"
    elsif data[:away_total].to_i > data[:home_total].to_i
      data[:margin] = data[:away_total].to_i - data[:home_total].to_i
      result[:final3] = "*#{data[:away_team_short]} by #{data[:margin]}*"
    elsif data[:away_total].to_i == data[:home_total].to_i
      data[:margin] = "0"
      result[:final3] = "Scores level."
    elsif data[:home_total].to_i == data[:away_total].to_i
      data[:margin] = "0"
      result[:final3] = "Scores level."
    end

    result[:final] = "#{result[:final1]} \n#{result[:final2]} \n#{result[:final3]}"
  end
end

module Stats
  def self.get_gameid(team)
    # Returns hash of:
    # :gameid
    # :home_team
    # :away_team

    games = open("http://dtlive.com.au:80/afl/viewgames.php").read
    in_progress = games.scan(/GameID=(\d+)">[^>]+>\s+(?:([A-Za-z ]+[^<]+)\s+vs[^>]+>\s*([^>]+)|([^>]+)\s+vs[^>]+>\s*([A-Za-z ]+[^<]+))\s+\(in progress\)</)
    completed = games.scan(/GameID=(\d+)">[^>]+>\s+(?:([A-Za-z ]+[^<]+)\s+vs[^>]+>\s*([^>]+)|([^>]+)\s+vs[^>]+>\s*([A-Za-z ]+[^<]+))<small>\(completed\)<\/small></)

    in_progress_game = in_progress.find { |array| array.include? team}
    completed_game = completed.find { |array| array.include? team}
    result_hash = {}

    if in_progress_game != nil # If the team is playing
      result_hash[:gameid] = in_progress_game[0]
      result_hash[:home_team] = in_progress_game[1] # Hometeam is always first
      result_hash[:away_team] = in_progress_game[2]
      return result_hash # Return the current game id
    elsif in_progress_game == nil # If the team isn't playing
      result_hash[:gameid] = completed_game[0]
      result_hash[:home_team] = completed_game[1] # Hometeam is always first
      result_hash[:away_team] = completed_game[2]
      return result_hash # Return most recent game ID (probably)
    end

  end # End of get_gameid


  def self.get_stats(gameid)

    feed = open("http://dtlive.com.au/afl/xml/#{gameid}.xml").read
    feed = Nokogiri::XML(feed)
    home_stats = feed.css('Home')
    away_stats = feed.css('Away')
    stats = []
    home_stats.css("Player").each do |player|
      playerstats = { :id => "#{player.css("PlayerID").inner_html}".to_i,
                      :name => "#{player.css("Name").inner_html}",
                      :team => "#{feed.css("Game").css("HomeTeam").inner_html}",
                      :number => "#{player.css("JumperNumber").inner_html}".to_i,
                      :possessions => "#{player.css("Kick").inner_html}".to_i + "#{player.css("Handball").inner_html}".to_i,
                      :kicks => "#{player.css("Kick").inner_html}".to_i,
                      :handballs => "#{player.css("Handball").inner_html}".to_i,
                      :marks => "#{player.css("Mark").inner_html}".to_i,
                      :tackles => "#{player.css("Tackle").inner_html}".to_i,
                      :freesfor => "#{player.css("FreeFor").inner_html}".to_i,
                      :freesagainst => "#{player.css("FreeAgainst").inner_html}".to_i,
                      :goals => "#{player.css("Goal").inner_html}".to_i,
                      :behinds => "#{player.css("Behind").inner_html}".to_i,
                      :score => 6 * "#{player.css("Goal").inner_html}".to_i + "#{player.css("Behind").inner_html}".to_i,
                      :togperc => "#{player.css("TOGPerc").inner_html}".to_i,
                      :dt => "#{player.css("DT").inner_html}".to_i }
      stats << playerstats
    end
    away_stats.css("Player").each do |player|
      playerstats = { :id => "#{player.css("PlayerID").inner_html}".to_i,
                      :name => "#{player.css("Name").inner_html}",
                      :team => "#{feed.css("Game").css("AwayTeam").inner_html}",
                      :number => "#{player.css("JumperNumber").inner_html}".to_i,
                      :possessions => "#{player.css("Kick").inner_html}".to_i + "#{player.css("Handball").inner_html}".to_i,
                      :kicks => "#{player.css("Kick").inner_html}".to_i,
                      :handballs => "#{player.css("Handball").inner_html}".to_i,
                      :marks => "#{player.css("Mark").inner_html}".to_i,
                      :tackles => "#{player.css("Tackle").inner_html}".to_i,
                      :freesfor => "#{player.css("FreeFor").inner_html}".to_i,
                      :freesagainst => "#{player.css("FreeAgainst").inner_html}".to_i,
                      :goals => "#{player.css("Goal").inner_html}".to_i,
                      :behinds => "#{player.css("Behind").inner_html}".to_i,
                      :score => 6 * "#{player.css("Goal").inner_html}".to_i + "#{player.css("Behind").inner_html}".to_i,
                      :togperc => "#{player.css("TOGPerc").inner_html}".to_i,
                      :dt => "#{player.css("DT").inner_html}".to_i }
      stats << playerstats
    end

    return stats

  end # End of get_stats

  def self.get_top_ten(gameid)

    top_ten = get_stats(gameid).sort_by { |player| player[:dt] }.reverse!.slice(0,10)

    top_ten_msg = "Top players of the game: \n"

    top_ten.each do |player|
      rank = top_ten.index(player).to_i + 1
      msg_line = "#{rank}: (#{$emotes[player[:team]]} ##{player[:number]}) #{player[:name]} | #{player[:dt]} DT Points | #{player[:possessions]} Possessions | Score (g.b.t): #{player[:goals]}.#{player[:behinds]}.#{player[:score]}\n"
      top_ten_msg << msg_line
    end

    return top_ten_msg

  end # End of get_top_ten

end
