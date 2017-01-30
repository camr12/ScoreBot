require 'json'
require 'tzinfo'
require 'active_support/core_ext/enumerable'
require 'pp'
require 'time'
require 'uri'
require 'net/http'

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

  def self.fetch_matches
    uri = URI('http://cricapi.com/api/matches/?apikey=1iHvVPXRR5RHEArkjQlIntupKkb2') # fetch json for match list
    JSON.parse(Net::HTTP.get(uri))['matches'] # parse match list as hash
  end

  def self.fetch_score(id)
    uri = URI("http://cricapi.com/api/cricketScore?apikey=1iHvVPXRR5RHEArkjQlIntupKkb2&unique_id=#{id}") # fetch json for matchs core
    JSON.parse(Net::HTTP.get(uri)) # parse score list as hash
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
    elsif score['matchStarted'] == true && !score['innings-requirement'].include?('toss') && !score['innings-requirement'].include?('won')
      score_dirty = score['score']
      score_clean = score_dirty.sub(/^([\w ]+) (\d+)\/(\d+)/, '\1 \3/\2')
      rr = Cric.runrate(score_clean)
      required = score['innings-requirement']
      result[:final] = "#{score_clean} - #{rr} RPO. \n \n#{required}"
      result[:final]
    elsif score['matchStarted'] == true && !score['innings-requirement'].include?('toss') && score['innings-requirement'].include?('won')
      result[:date_raw] = Time.parse(gmttime(score['dateTimeGMT']))
      result[:date] = result[:date_raw].strftime('%A %e %B.')
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
