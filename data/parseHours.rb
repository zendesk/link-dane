require 'csv'
require 'byebug'


MONDAY = /Mo(n(day(s)?)?)?/
TUESDAY = /Tu(e(sday(s)?)?)?/
WEDNESDAY = /We(d(nesday(s)?)?)?/
THURSDAY = /Th(u(rsday(s)?)?)?/
FRIDAY = /Fr(i(day(s)?)?)?/
SATURDAY = /Sa(t(urday(s)?)?)?/
SUNDAY = /Su(n(day(s)?)?)?/
WEEKDAY = /#{MONDAY}|#{TUESDAY}|#{WEDNESDAY}|#{THURSDAY}|#{FRIDAY}|#{SATURDAY}|#{SUNDAY}/
# WEEKDAY = /(Mo(n(day)?)?|Tu(e(sday)?)?|We(d(nesday)?)?|Th(u(rsday)?)?|Fr(i(day)?)?|Sa(t(urday)?)?|Su(n(day)?)?)/ 
WEEKDAY_RANGE = /(?<start_day>#{WEEKDAY})\s*-\s*(?<end_day>#{WEEKDAY})/
WEEKDAY_LIST = /#{WEEKDAY}(, #{WEEKDAY})*(,? and #{WEEKDAY})?/
TIME_R = /\d?\d:\d\d\s*[ap]m/i
TIME_RANGE_R =  /(?<start_time>#{TIME_R})\s*-\s*(?<end_time>#{TIME_R})/
FINAL = /(#{WEEKDAY_RANGE}|(?<weekdays>#{WEEKDAY_LIST}|[Dd]aily)),?\s*#{TIME_RANGE_R}/

FLAG = {missing: "NO_DATA", match: "", no_match: "NOT_PARSEABLE", twenty_four: "Confirm 24 hours"  }

def parse_csv_hours
  filename = 'parse_help.csv'

  # Load the original CSV file
  rows = CSV.read(filename, headers: true, encoding: "ISO-8859-1", return_headers: false).collect do |row|
    hash = row.to_hash

    program_hours = hash["Parsed Program Hours"]
    puts program_hours
    # parse_hours(program_hours)

  end

end

def parse_hours(hours)
  parsed = check_hours(hours)

  if parsed == :missing || parsed === :no_match
    return nil
  elsif parsed == :twenty_four
    return 24_hour_json
  else
    convert_hours(parsed)
  end
    
end

def parseable?(hours)
  hours.split(/;/).each do |h|
    matches = []
    FINAL.match(h.strip) do |m|
      matches << m.string
    end
    return false if matches.empty?

    return matches
  end
end

def is_24hours?(hours)
  /24\s*[hH]ours/.match(hours) do |h|
    return true
  end
  return false
end

def check_hours(hours)
  if !hours
    return :missing
  elsif is_24hours?(hours)
    return :twenty_four
  elsif matched = parseable?(hours)
    return matched
  else
    return :no_match
  end
end

# def check_hours(hours)
#   if !hours
#     return FLAG[:missing]
#   elsif is_24hours?(hours)
#     return FLAG[:twenty_four]
#   elsif matched = parseable?(hours)
#     return matched.inspect
#   else
#     return FLAG[:no_match]
#   end
# end


def mark_unparseable_hours(*args)
  filename = 'parse_help.csv'

  # Load the original CSV file
  ph_up, bh_up, bh_missing, ph_missing = 0, 0, 0, 0
  rows = CSV.read(filename, headers: true, encoding: "ISO-8859-1", return_headers: false).collect do |row|
    hash = row.to_hash

    # building_hours = hash["BUILDING HOURS"]
    program_hours = hash["Parsed Program Hours"]
    
    # Assign a flag for building and program hours
    # bh_flag = check_hours(building_hours)
    ph_flag = check_hours(program_hours)

    
    # Calculate statistics
    # if bh_flag == FLAG[:no_match]
    #   bh_up = bh_up + 1
    #   # puts "BH: #{building_hours}"
    # elsif bh_flag == FLAG[:missing]
    #   bh_missing = bh_missing + 1
    # end
    if ph_flag == FLAG[:no_match]
      ph_up = ph_up + 1
      puts "PH: #{program_hours}"
    elsif ph_flag == FLAG[:missing]
      ph_missing = ph_missing + 1
    end

    # Merge additional data as a hash.
    hash.merge('Program Hours FLAG' => ph_flag)
    # hash.merge('Building Hours FLAG' => bh_flag, 'Program Hours FLAG' => ph_flag)
  end
  puts "PH unparseable: #{ph_up}"
  # puts "BH unparseable: #{bh_up}"
  # puts "BH missing: #{bh_missing}"
  puts "PH missing: #{ph_missing}"
  puts "Total rows: #{rows.count}"

  # # Extract column names from first row of data
  column_names = rows.first.keys
  txt = CSV.generate do |csv|
    csv << column_names
    rows.each do |row|
      # Extract values for row of data
      csv << row.values
    end
  end

  # Write to new csv file
  File.open('marked_hours.csv', 'w') { |file| file.write(txt) }
        
end

parse_csv_hours
# mark_unparseable_hours
