require 'json'
require 'tzinfo'
require 'active_support/core_ext/enumerable'
require 'pp'



module Cric

  def Cric.gmt(time=nil) # fix this, shouldn't be using local_to_utc - it doesn't make sense
    tz = TZInfo::Timezone.get('Australia/Sydney')
    time += ' UTC'
    time = Time.parse(time)
    time = tz.local_to_utc(time)
    tz.strftime('%Y-%m-%d %H:%M:%S %Z', time)
  end

  def Cric.fetch_matches
    uri = URI('http://cricapi.com/api/matches/?apikey=1iHvVPXRR5RHEArkjQlIntupKkb2')
    JSON.parse(Net::HTTP.get(uri))['matches']
  end

  def Cric.fetch_score(id)
    uri = URI("http://cricapi.com/api/cricketScore?apikey=1iHvVPXRR5RHEArkjQlIntupKkb2&unique_id=#{id}")
    JSON.parse(Net::HTTP.get(uri))
  end

  def Cric.cricket_score(team) # Dont set team=nil, its not optional
    id = fetch_matches.find { | h | h.key(team) }['unique_id']

    score = fetch_score(id)
    result = {}

    if score.key?('score') and ["score"].include?('Match')
      result[:final] = score["innings-requirement"] << "    "
      result[:final]
    elsif score["innings-requirement"].include?('scheduled') and score["team-2"].include?(team)
      result[:schedule] = score["innings-requirement"]
      result[:team] = score["team-1"]
      result[:date_raw] = Time.parse(gmt(score["dateTimeGMT"]))
      result[:date] = result[:date_raw].strftime("%B %-d, %Y")
      result[:final] = "#{result[:schedule]} against #{result[:team]} on #{result[:date]}." << "  "
      result[:final]
    elsif score["innings-requirement"].include?('scheduled') and score["team-1"].include?(team)
      result[:schedule] = score["innings-requirement"]
      result[:team] = score["team-2"]
      result[:date_raw] = Time.parse(gmt(score["dateTimeGMT"]))
      result[:date] = result[:date_raw].strftime("%B %-d, %Y")
      result[:final] = "#{result[:schedule]} against #{result[:team]} on #{result[:date]}." << " "
      result[:final]
    elsif score["matchStarted"] == true and score["innings-requirement"].include?('elected')
      result[:final] = score["innings-requirement"] << "  "
      result[:final]
    elsif score["matchStarted"] == true
      score-dirty = score["score"]
      result[:final] = score_dirty.sub(/^([\w ]+) (\d+)\/(\d+)/, '\1 \3/\2')
      result[:final]
    end
  end


  def Cric.runrate(score) # again, no nil - this isnt optional
    overs =  /\(([0-9]+)\.([0-9]+)?/.match(score)[1]
    runs = match_groups = /(\d+)\/(\d+)/.match(score)[2]
    balls = /\(([0-9]+)\.([0-9]+)?/.match(score)[2]
    rate1 = runs.to_f * 6 / ((overs.to_f * 6) + balls.to_f)
    rate2 = '%.2f' % rate1
  end


end
module Afl

end
