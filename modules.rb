require 'json'
require 'tzinfo'
require 'active_support/core_ext/enumerable'
require 'pp'

# Module for checking cricket scores/schedules using the CricAPI
module Cric
  def self.gmt(time = nil) # don't uselocal_to_utc - doesn't make sense
    tz = TZInfo::Timezone.get('Australia/Sydney')
    time += ' UTC'
    time = Time.parse(time)
    time = tz.local_to_utc(time)
    tz.strftime('%Y-%m-%d %H:%M:%S %Z', time)
  end

  def self.fetch_matches
    uri = URI('http://cricapi.com/api/matches/?apikey=1iHvVPXRR5RHEArkjQlIntupKkb2')
    JSON.parse(Net::HTTP.get(uri))['matches']
  end

  def self.fetch_score(id)
    uri = URI("http://cricapi.com/api/cricketScore?apikey=1iHvVPXRR5RHEArkjQlIntupKkb2&unique_id=#{id}")
    JSON.parse(Net::HTTP.get(uri))
  end

  def self.cricket_score(team) # Dont set team=nil, its not optional
    id = fetch_matches.find { |h| h.key(team) }['unique_id']

    score = fetch_score(id)
    result = {}

    if score.key?('score') && ['score'].include?('Match')
      result[:final] = score['innings-requirement'] << '    '
      result[:final]
    elsif score['innings-requirement'].include?('scheduled') && score['team-2'].include?(team)
      result[:schedule] = score['innings-requirement']
      result[:team] = score['team-1']
      result[:time_raw] = Time.parse(gmt(score['dateTimeGMT']))
      result[:date] = result[:time_raw].strftime("%B %-d, %Y")
      result[:time_dirty] = result[:time_raw].strftime('%l %p')
      result[:schedule].gsub!(/at\s(.*?\stime)/, "at#{result[:time_dirty]} Sydney time (\\1)")
      result[:schedule].gsub!(/\(\d\d:\d\d GMT\)/, "")
      result[:final] = "#{result[:schedule]}against *#{result[:team]}* on #{result[:date]}." << ' '
      result[:final]
    elsif score['innings-requirement'].include?('scheduled') && score['team-1'].include?(team)
      result[:schedule] = score['innings-requirement']
      result[:team] = score['team-2']
      result[:time_raw] = Time.parse(gmt(score['dateTimeGMT']))
      result[:date] = result[:date_raw].strftime("%B %-d, %Y")
      result[:time_dirty] = result[:time_raw].strftime('%l %p')
      result[:schedule].gsub!(/at\s(.*?\stime)/, "at#{result[:time_dirty]} Sydney time (\\1)")
      result[:schedule].gsub!(/\(\d\d:\d\d GMT\)/, "")
      result[:final] = "#{result[:schedule]}against *#{result[:team]}* on #{result[:date]}." << ' '
      result[:final]
    elsif score['matchStarted'] == true && !score['innings-requirement'].include?('toss') && !score['innings-requirement'].include?('won')
      score_dirty = score['score']
      score_clean = score_dirty.sub(/^([\w ]+) (\d+)\/(\d+)/, '\1 \3/\2')
      rr = Cric.runrate(score_clean)
      required = score['innings-requirement']
      result[:final] = "#{score_clean} - #{rr} RPO. \n \n#{required}"
      result[:final]
    elsif score['matchStarted'] == true && !score['innings-requirement'].include?('toss') && score['innings-requirement'].include?('won')
      result[:date_raw] = Time.parse(gmt(score['dateTimeGMT']))
      result[:date] = result[:date_raw].strftime('%A %e %B at %l %p Sydney time.')
      result[:final] = "#{score['innings-requirement']} on #{result[:date]}"
      result[:final]
    elsif score['matchStarted'] == true
      score_dirty = score['score']
      rr = runrate(score_dirty)
      score_clean = score_dirty.sub(/^([\w ]+) (\d+)\/(\d+)/, '\1 \3/\2')
      result[:final] = "#{score_clean} \n \n#{rr} RPO"
      result[:final]
    end
  end

  def self.runrate(score) # again, no nil - this isnt optional
    overs = /\(([0-9]+)\.([0-9]+)?/.match(score)[1]
    runs = match_groups = /(\d+)\/(\d+)/.match(score)[2]
    balls = /\(([0-9]+)\.([0-9]+)?/.match(score)[2]
    rate1 = runs.to_f * 6 / ((overs.to_f * 6) + balls.to_f)
    rate2 = '%.2f' % rate1
  end
end

# Module for checking live AFL scores and past games
module Afl
end
