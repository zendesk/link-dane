require 'csv'
require 'json'
require 'byebug'


MONDAY = /Mo(n(day(s)?)?)?/
TUESDAY = /Tu(e(sday(s)?)?)?/
WEDNESDAY = /We(d(nesday(s)?)?)?/
THURSDAY = /Th(u(rsday(s)?)?)?/
FRIDAY = /Fr(i(day(s)?)?)?/
SATURDAY = /Sa(t(urday(s)?)?)?/
SUNDAY = /Su(n(day(s)?)?)?/
WEEKDAY = /#{MONDAY}|#{TUESDAY}|#{WEDNESDAY}|#{THURSDAY}|#{FRIDAY}|#{SATURDAY}|#{SUNDAY}/
WEEKDAY_RANGE = /(?<start_day>#{WEEKDAY})\s*-\s*(?<end_day>#{WEEKDAY})/
WEEKDAY_OR_RANGE = /((?<weekday_range>#{WEEKDAY_RANGE})|(?<weekday>#{WEEKDAY}))/
WEEKDAY_LIST = /#{WEEKDAY_OR_RANGE}(, #{WEEKDAY_OR_RANGE})*(,? and #{WEEKDAY_OR_RANGE})?/
WEEKDAY_LIST_R = /#{WEEKDAY_OR_RANGE}(, #{WEEKDAY_OR_RANGE})+(,? and #{WEEKDAY_OR_RANGE})?/
TIME = /\d?\d:\d\d\s*[ap]m/i
TIME_RANGE =  /(?<start_time>#{TIME})\s*-\s*(?<end_time>#{TIME})/
TIME_RANGE_LIST = /#{TIME_RANGE}(,\s*#{TIME_RANGE})*/ 
TIME_RANGE_LIST = /#{TIME_RANGE}(,\s*#{TIME_RANGE})+/ 
DAYTIME_RANGE = /(?<weekday_list>#{WEEKDAY_LIST})[,:]?\s*(?<timerange_list>#{TIME_RANGE_LIST})/
# {"openHours": {"1": [[900, 1700 ] ], "2": [[900, 1700 ] ], "3": [[900, 1700 ] ], "4": [[900, 1700 ] ], "5": [[900, 1700 ] ]}}

FLAG = {missing: "NO_DATA", match: "", no_match: "NOT_PARSEABLE", twenty_four: "Confirm 24 hours"  }
CONVERT_WEEKDAYS = {sunday: 0, monday: 1,tuesday: 2,wednesday: 3,thursday: 4,friday: 5,saturday: 6}

def parse_csv_hours
  filename = 'parse_help.csv'

  # Load the original CSV file
  rows = CSV.read(filename, headers: true, encoding: "ISO-8859-1", return_headers: false).collect do |row|
    hash = row.to_hash

    program_hours = hash["Parsed Program Hours"]
    parse_hours(program_hours)
  end

end

def parse_hours(hours)
  parsed = check_hours(hours)

  if parsed == :missing || parsed === :no_match
    nil
  elsif parsed == :twenty_four
    json_24hours
  else
    convert_hours(parsed)
  end
end

# [#<MatchData "Monday-Thursday 10:00am-12:00pm,  2:00pm-7:00pm" weekday_list:"Monday-Thursday" start_day:"Monday" end_day:"Thursday" start_day:nil end_day:nil start_day:nil end_day:nil timerange_list:"10:00am-12:00pm,  2:00pm-7:00pm" start_time:"10:00am" end_time:"12:00pm" start_time:"2:00pm" end_time:"7:00pm">, #<MatchData "Friday 10:00am-5:00pm" weekday_list:"Friday" start_day:nil end_day:nil start_day:nil end_day:nil start_day:nil end_day:nil timerange_list:"10:00am-5:00pm" start_time:"10:00am" end_time:"5:00pm" start_time:nil end_time:nil>, #<MatchData "Saturday 10:00am-1:00pm" weekday_list:"Saturday" start_day:nil end_day:nil start_day:nil end_day:nil start_day:nil end_day:nil timerange_list:"10:00am-1:00pm" start_time:"10:00am" end_time:"1:00pm" start_time:nil end_time:nil>]

# [#<MatchData "Wednesday, Thursday 9:00am - 8:00pm" weekday_list:"Wednesday, Thursday" start_day:nil end_day:nil start_day:nil end_day:nil start_day:nil end_day:nil timerange_list:"9:00am - 8:00pm" start_time:"9:00am" end_time:"8:00pm" start_time:nil end_time:nil>, #<MatchData "Tuesday, Friday 9:00am - 5:00pm" weekday_list:"Tuesday, Friday" start_day:nil end_day:nil start_day:nil end_day:nil start_day:nil end_day:nil timerange_list:"9:00am - 5:00pm" start_time:"9:00am" end_time:"5:00pm" start_time:nil end_time:nil>, #<MatchData "Saturday 10:00am - 2:00pm" weekday_list:"Saturday" start_day:nil end_day:nil start_day:nil end_day:nil start_day:nil end_day:nil timerange_list:"10:00am - 2:00pm" start_time:"10:00am" end_time:"2:00pm" start_time:nil end_time:nil>]

def convert_hours(matched_hours)
  json_hours = {}
  matched_hours.each do |daytime_range|
    days = []
    ranges = []
    # Parse Weekday and Timerange lists
    weekdays = daytime_range['weekday_list']
    timeranges = daytime_range['timerange_list']
    
    # Check if the matched weekdays is a List
    WEEKDAY_LIST_R.match(weekdays) do |list|
      type = :list
      # Extract weekdays from each range/day item
      list.split(/,/).each do |daylist_item|
        extract_weekdays(daylist_item, days)
      end
    end
    # Otherwise if not a list, extract weekdays from the range/day
    extract_weekdays(weekdays, days) unless type
    
    
  end


  puts matched_hours.inspect
end


# Extracts weekdays from  WEEKDAY_OR_RANGE
def extract_weekdays(weekdays, extracted)
  WEEKDAY_OR_RANGE.match(weekdays) do |day_match|
    if day_match['weekday_range']
      start_day = find_weekday(day_match['start_day'])
      end_day = find_weekday(day_match['end_day'])

      # Handle edge case end_day < start_day for ranges
      end_day += 7 if end_day < start_day
      day_range = (start_day..end_day).to_a.map { |n| n % 7 }
      
      day_range.each { |d| extracted << d }
    else
      extracted << find_weekday(day_match['weekday']
    end
  end
end

def find_weekday(day)
  case
  when SUNDAY.match(day)
    CONVERT_WEEKDAYS[:sunday]
  when MONDAY.match(day)
    CONVERT_WEEKDAYS[:monday]
  when TUESDAY.match(day)
    CONVERT_WEEKDAYS[:tuesday]
  when WEDNESDAY.match(day)
    CONVERT_WEEKDAYS[:wednesday]
  when THURSDAY.match(day)
    CONVERT_WEEKDAYS[:thursday]
  when FRIDAY.match(day)
    CONVERT_WEEKDAYS[:friday]
  when SATURDAY.match(day)
    CONVERT_WEEKDAYS[:saturday]
  else
    nil
  end

end

def is_24hours?(hours)
  /24\s*[hH]ours/.match(hours) do |h|
    return true
  end
  return false
end

def json_24hours
  {"0" => [[000,2359]], "1" => [[000,2359]], "2" => [[000,2359]], "3" => [[000,2359]], "4" => [[000,2359]], "5" => [[000,2359]], "6" => [[000,2359]]}.to_json
end

def parseable?(hours)
  matches = []
  hours.split(/;/).each do |h|
    DAYTIME_RANGE.match(h.strip) do |m|
      matches << m
    end
  end

  matches.empty? ? false : matches
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

  # initialize unparseable/missing counts
  ph_up, bh_up, bh_missing, ph_missing = 0, 0, 0, 0
  # Load the original CSV file
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
