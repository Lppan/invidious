# See http://www.evanmiller.org/how-not-to-sort-by-average-rating.html
def ci_lower_bound(pos, n)
  if n == 0
    return 0.0
  end

  # z value here represents a confidence level of 0.95
  z = 1.96
  phat = 1.0*pos/n

  return (phat + z*z/(2*n) - z * Math.sqrt((phat*(1 - phat) + z*z/(4*n))/n))/(1 + z*z/n)
end

def elapsed_text(elapsed)
  millis = elapsed.total_milliseconds
  return "#{millis.round(2)}ms" if millis >= 1

  "#{(millis * 1000).round(2)}µs"
end

def make_client(url)
  context = OpenSSL::SSL::Context::Client.new
  context.add_options(
    OpenSSL::SSL::Options::ALL |
    OpenSSL::SSL::Options::NO_SSL_V2 |
    OpenSSL::SSL::Options::NO_SSL_V3
  )
  client = HTTP::Client.new(url, context)
  client.read_timeout = 10.seconds
  client.connect_timeout = 10.seconds
  return client
end

def decode_length_seconds(string)
  length_seconds = string.split(":").map { |a| a.to_i }
  length_seconds = [0] * (3 - length_seconds.size) + length_seconds
  length_seconds = Time::Span.new(length_seconds[0], length_seconds[1], length_seconds[2])
  length_seconds = length_seconds.total_seconds.to_i

  return length_seconds
end

def decode_time(string)
  time = string.try &.to_f?

  if !time
    hours = /(?<hours>\d+)h/.match(string).try &.["hours"].try &.to_f
    hours ||= 0

    minutes = /(?<minutes>\d+)m(?!s)/.match(string).try &.["minutes"].try &.to_f
    minutes ||= 0

    seconds = /(?<seconds>\d+)s/.match(string).try &.["seconds"].try &.to_f
    seconds ||= 0

    millis = /(?<millis>\d+)ms/.match(string).try &.["millis"].try &.to_f
    millis ||= 0

    time = hours * 3600 + minutes * 60 + seconds + millis / 1000
  end

  return time
end

def decode_date(string : String)
  # String matches 'YYYY'
  if string.match(/\d{4}/)
    return Time.new(string.to_i, 1, 1)
  end

  # String matches format "20 hours ago", "4 months ago"...
  date = string.split(" ")[-3, 3]
  delta = date[0].to_i

  case date[1]
  when .includes? "second"
    delta = delta.seconds
  when .includes? "minute"
    delta = delta.minutes
  when .includes? "hour"
    delta = delta.hours
  when .includes? "day"
    delta = delta.days
  when .includes? "week"
    delta = delta.weeks
  when .includes? "month"
    delta = delta.months
  when .includes? "year"
    delta = delta.years
  else
    raise "Could not parse #{string}"
  end

  return Time.now - delta
end

def recode_date(time : Time)
  span = Time.now - time

  if span.total_days > 365.0
    span = {span.total_days / 365, "year"}
  elsif span.total_days > 30.0
    span = {span.total_days / 30, "month"}
  elsif span.total_days > 7.0
    span = {span.total_days / 7, "week"}
  elsif span.total_hours > 24.0
    span = {span.total_days, "day"}
  elsif span.total_minutes > 60.0
    span = {span.total_hours, "hour"}
  elsif span.total_seconds > 60.0
    span = {span.total_minutes, "minute"}
  else
    span = {span.total_seconds, "second"}
  end

  span = {span[0].to_i, span[1]}
  if span[0] > 1
    span = {span[0], span[1] + "s"}
  end

  return span.join(" ")
end

def number_with_separator(number)
  number.to_s.reverse.gsub(/(\d{3})(?=\d)/, "\\1,").reverse
end

def arg_array(array, start = 1)
  if array.size == 0
    args = "NULL"
  else
    args = [] of String
    (start..array.size + start - 1).each { |i| args << "($#{i})" }
    args = args.join(",")
  end

  return args
end

def make_host_url(ssl, host)
  if ssl
    scheme = "https://"
  else
    scheme = "http://"
  end

  host ||= "invidio.us"

  return "#{scheme}#{host}"
end