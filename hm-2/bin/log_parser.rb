require 'time'
require 'yajl'

def parse_log(log_file_name)

  File.new(log_file_name).each do |line|
    m = /\[(?<timestamp>[^\]]+)\].+(?<level>DEBUG|INFO|ERROR) \-\- (?<payload>.+)/.match(line)

    unless m
      puts "skipping unparseable #{line}"
      next
    end

    yield m[:timestamp], m[:level], m[:payload]

  end

end

@count = 0

histo = {}
t0 = nil

stops = {}
restarts = {}

parse_log(ARGV.shift || 'health_manager.log') do |*args|


  ts, level, payload = args
begin
  ts = Time.strptime(ts,'%Y-%m-%d %H:%M:%S').to_i
  t0 ||= ts
  ts -= t0

  if payload =~ /CRASHED/
    m = /app_id\=(?<app_id>\d+), index=(?<index>\d+)/.match(payload)
    app_id, index = m[:app_id], m[:index]
    stops[app_id] ||= {}
    stops[app_id][index] ||= {}
    stops[app_id][index][:count] ||= 0
    stops[app_id][index][:count] += 1
    stops[app_id][index][:last] ||= ts

  elsif payload =~ /^Requesting the start/
    json = payload[/\{.+\}/]
    obj = Yajl::Parser.parse(json)
    app_id = obj["droplet"].to_s
    index = obj["indices"].shift.to_s

    if stops[app_id] && stops[app_id][index]

      lapse = ts - stops[app_id][index][:last]
#      puts "#{app_id}, #{index} restarting after #{lapse} since CRASH" if lapse > 5

      restarts[lapse] ||= 0
      restarts[lapse] += 1

    end
#    break if (@count+=1) > 100
  end

rescue
  puts "Error parsing #{payload}"
  exit 1
end



end

stops = stops.find_all { |app_id, inds| inds.any? {|ind, entry| entry[:count]>2}}

#puts restarts.inspect

puts stops.inspect
