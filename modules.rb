require 'json'
require 'tzinfo'
require 'active_support/core_ext/enumerable'
require 'pp'
require 'time'
require 'uri'
require 'net/http'
require 'nokogiri'
require 'open-uri'

# Module for checking cricket scores/schedules using the CricAPI
module Cric
  #  def self.gmt(time = nil) # don't use local_to_utc - doesn't make sense
  #    tz = TZInfo::Timezone.get('Australia/Sydney')
  #    time += ' UTC'
  #    time = Time.parse(time)
  #    time = tz.local_to_utc(time)
  #    tz.strftime('%Y-%m-%d %H:%M:%S %Z', time)
  #  end

  #def self.gmt(t = nil) # convert GMT time to Sydney time (AEDT/AEST)
  #  t2 = tz.utc_to_local(t1)
  #  #t2 = t1 + t1.utc_offset # parse gmt_offset to local Sydney time
  #  t3 = t2.strftime("%F %T") # remove redundant gmt_offset
  #  t4 = t3.strftime("%I:%M %p") # convert to "hour:second PM/AM"
  #end

  def self.gmttime(tstr) # convert GMT time to timezone defined by tz variable
    tz = TZInfo::Timezone.get('Australia/Sydney') # timezone to convert to
    time = Time.parse(tstr) # parse time
    tz.utc_to_local(time).strftime("%I:%M %p") # convert to "hour:second AM/PM" and timezone
  end

  def self.gmtdate(tstr)
    tz = TZInfo::Timezone.get('Australia/Sydney') # timezone to convert to
    time = Time.parse(tstr) # parse time
    tz.utc_to_local(time).strftime("%B %d, %Y") # convert to "hour:second AM/PM" and timezone
  end

  def self.fetch_matchescric
    uri = URI('http://cricapi.com/api/matches/?apikey=1iHvVPXRR5RHEArkjQlIntupKkb2') # fetch json for match list
    JSON.parse(Net::HTTP.get(uri))['matches'] # parse match list as hash
  end

  def self.fetch_scorecric(id)
    uri = URI("http://cricapi.com/api/cricketScore?apikey=1iHvVPXRR5RHEArkjQlIntupKkb2&unique_id=#{id}") # fetch json for matchs core
    JSON.parse(Net::HTTP.get(uri)) # parse score list as hash
  end

  def self.cricket_score(team) # Dont set team=nil, its not optional
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

  def self.runrate(score) # again, no nil - this isnt optional
    overs = /\(([0-9]+)\.([0-9]+)?/.match(score)[1]
    runs = match_groups = /(\d+)\/(\d+)/.match(score)[1]
    balls = /\(([0-9]+)\.([0-9]+)?/.match(score)[2]
    rate1 = runs.to_f * 6 / ((overs.to_f * 6) + balls.to_f)
    rate2 = '%.2f' % rate1
  end
end

# Module for checking live AFL scores and past games
module Afl


  def self.afl_score(team)

    tz = TZInfo::Timezone.get('Australia/Sydney')

    teamnames = {'Carlton' => 'CARL', 'Richmond' => 'RICH', 'Collingwood' => 'COLL', 'Bulldogs' => 'WB', 'St Kilda' => 'STK', 'Melbourne' => 'MEL', 'Sydney' => 'SYD', 'Port Adelaide' => 'PORT', 'Gold Coast Suns' => 'GC', 'Brisbane Lions' => 'BRIS', 'Essendon' => 'ESS', 'Hawthorn' => 'HAW', 'North Melbourne' => 'NMFC', 'West Coast' => 'WCE', 'Adelaide' => 'ADEL', 'GWS' => 'GWS', 'Fremantle' => 'FRE', 'GEEL' => 'Geelong'}

    if teamnames.include?(team)
      shortteamdirty = teamnames.select{|k,v| k == team}
      shortteamclean = shortteamdirty[team]
    end


    uri = URI('http://afl.lookoutdata.com/live/feeds/m//widget/1/default/') # fetch json for matchs core
    matchesdirty = JSON.parse(Net::HTTP.get(uri)) # parse json as hash
    matchesclean = matchesdirty['c']['matches']

    matchentrydirty = matchesclean.find {|v| v['quickScore']['homeTeamName'] == shortteamclean || v['quickScore']['awayTeamName'] == shortteamclean }
    matchentryclean = matchentrydirty['quickScore']

    result = {}

    if matchentryclean['homeTeamName'] == shortteamclean
      id = matchentryclean['matchID']
    elsif matchentryclean['awayTeamName'] == shortteamclean
      id = matchentryclean['matchID']
    end


    result[:homeTeamDirty] = matchentryclean['homeTeamName']
    result[:homeTeam] =  teamnames.select {|_, v| v == result[:homeTeamDirty]}.keys[0]

    result[:awayTeamDirty] = matchentryclean['awayTeamName']
    result[:awayTeam] = teamnames.select {|_, v| v == result[:awayTeamDirty]}.keys[0]

    result[:homeScore] = matchentryclean['homeScore']
    result[:awayScore] = matchentryclean['awayScore']
    result[:venue] = matchentryclean['venueName']

    start_time_dirty = Time.parse(matchentryclean['utcStartTime'])
    start_time_dirty_converted = tz.utc_to_local(start_time_dirty)
    start_time_clean = start_time_dirty_converted.strftime('%I:%M %p')

    result[:starttime] = start_time_clean

    start_date_dirty = Time.parse(matchentryclean['utcStartTime'])
    start_date_dirty_converted = tz.utc_to_local(start_date_dirty)
    start_date_clean = start_date_dirty_converted.strftime('%b %d, %Y')

    result[:startdate] = start_date_clean

    result[:final] = "#{result[:homeTeam]}: #{result[:homeScore]} - #{result[:awayTeam]}: #{result[:awayScore]}"


  end

def self.get_id(team)
  team = team.split.map(&:capitalize).join(' ')
  games = open("http://dtlive.com.au/afl/viewgames.php").read

  gameid = games.match(/GameID=(\d+)">[^>]+>\s+(?:(#{team})\s+vs[^>]+>\s*([^>]+)|([^>]+)\s+vs[^>]+>\s*(#{team}))\s+(?!upcoming)</)[1]


  process_feed(gameid)

end

def self.process_feed(gameid)
  data = {}
  result = {}
  feed = open("http://dtlive.com.au/afl/xml/#{gameid}.xml").read
  feed = Nokogiri::XML(feed)

  teams = {"Port Adelaide" => ":port:", "Richmond" => ":tigers:", "Sydney" => ":swans:", "Gold Coast" => ":suns:", "Essendon" => ":dons:", "Hawthorn" => ":hawks:", "Brisbane" => ":lions:", "Melbourne" => ":dees:", "St Kilda" => ":saints:", "Fremantle" => ":freo:", "GWS Giants" => ":gws:", "North Melbourne" => ":norf:", "Carlton" => ":blues:", "Collingwood" => ":pies:", "Adelaide" => ":crows:", "Geelong" => ":cats", "West Coast" => ":eagles:", "Bulldogs" => ":dogs:"}
  teams.map { |k,v| [k, server.emoji.values.find { |e| e.name == v }.to_s] }.to_h 
  
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

  result[:final1] = "#{data[:home_team]} vs #{data[:away_team]} at #{data[:location]} - #{data[:perc_complete] == 100 ? "Game finished" : "Game time: #{data[:current_time]} in Q#{data[:current_qtr]}"}"
  result[:final2] = data[:home_total] > data[:away_total] ? "#{data[:home_team]} #{data[:perc_complete] == 100 ? "won" : "currently winning"} by #{(data[:home_total].to_i-data[:away_total].to_i)} points" : "#{data[:away_team]} #{data[:perc_complete] == 100 ? "won" : "currently winning"} by #{(data[:away_total].to_i-data[:home_total].to_i)} points"
  result[:final3] = "#{data[:home_team]} - Goals: (#{data[:home_goals]}) Behinds: (#{data[:home_points]}) Total: (#{data[:home_total]}) *vs* #{data[:away_team]} - Goals: (#{data[:away_goals]}) Behinds: (#{data[:away_points]}) Total: (#{data[:away_total]})"

  #result[:final] = "#{result[:final1]} \n#{result[:final2]} \n#{result[:final3]}"
  result[:final] = "#{teams[data[:home_team]]} #{data[:home_points]}.#{data[:home_goals]}.#{data[:home_total]} - #{teams[data[:away_team]]} #{data[:away_points]}.#{data[:away_goals]}.#{data[:away_total]}"
end
end
