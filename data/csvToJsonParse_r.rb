#!/usr/bin/env ruby

require 'json'
require 'csv'
require 'rails'
require 'geocoder'
require 'net/http'
require 'optparse'
require_relative 'parseHours'

PHONE_NUMBER = /(\(\d{3}\)[ -]\d{3}-\d{4})|(\(211\))/
PHONE_NUM_DESC = /\(\D+\)/
A = /\AA\z/i
OF = /\AOF\z/i
TO = /\ATO\z/i
AND = /\AAND\z/i
THE = /\ATHE\z/i
DE = /\ADE\z/i
HYPHEN = /-/i
A_HYPHEN = /\A-\z/i
YMCA = /^YMCA/i
YWCA = /^YWCA/i
UW = /^UW/i
JFF = /^JFF/i
WI = /\AWI\z/i
ABRV = /((#{UW})|(#{YMCA})|(#{JFF})|(#{WI})|(#{YWCA}))/
CONJ = /(#{A})|(#{OF})|(#{TO})|(#{AND})|(#{THE})|(#{DE})|(#{HYPHEN})|(#{A_HYPHEN})/
WORD_RANGE = /(#{ABRV})|(#{CONJ})/
INT_WORD_RANGE = /(#{ABRV})|(\sA\s)|(\sOF\s)|(\sTO\s)|(\sAND\s)|(\sTHE\s)|(\sDE\s)|(#{HYPHEN})/
begin

  ARGV << '-h' if ARGV.empty?

  $options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: ParseParser.rb [$options]"
    opts.on("-f", "--file fileName", String, "CSV file to parse") { |f| $options[:fileName] = f }
    $options[:entityToParse] = :b
    opts.on("-e", "--entity [type INITIAL]", [:f, :s, :b], "Entities to parse: (facilities, services, both)") { |e| $options[:entityToParse] = e}
    $options[:geocode] = :m
    opts.on("-g", "--geocode [service INITIAL]", [:m, :g, :mc, :gc], "Geocoding service: (mapbox, google or mapbox cache, googleCache)" ) { |g| $options[:geocode] = g}
    opts.on("-v", "--[no-]verbose", "Run verbosely") { |v| $options[:verbose] = v }

    opts.on_tail("-h", "--help", "Show this message") do
      puts opts
      exit
    end
  end.parse!

  raise OptionParser::MissingArgument if $options[:fileName].nil?
  raise OptionParser::MissingArgument if $options[:entityToParse].nil?
  raise OptionParser::MissingArgument if $options[:geocode].nil?

rescue OptionParser::MissingArgument
  puts "Incorrect argument for an option. Please check help"
  exit 1

rescue OptionParser::ParseError
  puts "Having trouble parsing options provided. Please check help"
  exit 1

else
  Geocoder.configure(:mapbox => {:timeout => 10, :dataset => "mapbox.places-permanent", :api_key => "pk.eyJ1IjoiejNucGNoaGV0cmkxIiwiYSI6ImNpa3RnaXFxMjAwNnN2Zm0zMG12OWNtM2oifQ.5PAfr7EbGkL_oDaKGmqhEQ"})
end


def main
  debug $options.inspect
  facilities = createFacilityHash()
  parseFacility(facilities) if $options[:entityToParse] == :f
  parseService() if $options[:entityToParse] == :s
  if $options[:entityToParse] == :b
    parseFacility(facilities)
    parseService()
  end
end


def createFacilityHash()
  # Creating facility hash to be used in creating the json for facility as well as geo-encoding
  sitesHash = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }

  CSV.foreach($options[:fileName], encoding: "ISO-8859-1", headers: true, return_headers: false) do |row|
    site = sitesHash[row['AgencyID']][row['SiteID']]
    if site['services'].empty?
      site['services'] = Array.new
    end
    site['services'].push row['ServiceID']
    !row['Address 1'].nil? ? site['address'] = row['Address 1'] : site['address'] = "600-702 Braxton Place"
    !row['City'].nil? ? site['city'] = row['City'] : site['city'] = "Madison"
    !row['Address 1'].nil? ? site['state'] = row['State'] : site['state'] = "WI"
    !row['Address 1'].nil? ? site['zipCode'] = row['ZIP Code'] : site['zipCode'] = "53715"

    if site['Gender'].empty?
      site['Gender'] = [row['Gender']]
    elsif !site['Gender'].empty?
      site['Gender'] << row['Gender']
    end

    ages = row['Ages'].split(", ")

    if site['Ages'].empty?
      site['Ages'] = ages
    elsif !site['Ages'].empty?
      site['Ages'].push(*ages)
    end

  end

  debug "The siteHash without geocode: \n #{sitesHash}"

  debug "Starting to geocode!"

  if $options[:geocode] != :mc and $options[:geocode] != :gc
    puts "Geocoding, this may take some time. Please be patient (especially if using Google)\n\n"

    sitesHash.each do |agencyID, siteID|
      siteID.each do |k,v|
        # debug "#{v}"
        geoLat, geoLong = googleGeoCode(v['address'],v['city'],v['state'],v['zipCode']) if $options[:geocode] == :g
        sleep 0.05.seconds
        geoLat, geoLong = mapBoxGeoCode(v['address'],v['city'],v['state'],v['zipCode']) if $options[:geocode] == :m
        v['location'] = Array.new()
        v['location'].push geoLat,geoLong
      end
    end
    data = YAML.dump(sitesHash)
    $options[:geocode] == :g ? open('sitesHashGoogle.yml', 'wb') { |f| f.puts data } : open('sitesHashMapbox.yml', 'wb') { |f| f.puts data }
    puts "Done fetching location, YAML file created to cache data"
  else
    puts 'Using cached location'
    data=File.read("sitesHashGoogle.yml") if $options[:geocode] == :gc
    data=File.read("sitesHashMapbox.yml") if $options[:geocode] == :mc
    sitesHashYAML = YAML.load(data)
    sitesHash = sitesHashYAML
    debug sitesHashYAML.inspect
  end

  return sitesHash
end

def mapBoxGeoCode(address, city, state, zip)
  puts 'MapBox Query  Address : ' + lookupAddress =[address,city,state,zip].join(' ')
  result = Geocoder.search([address,city,state,zip].join(',')).first
  puts 'MapBox Result Address : ' + result.address + "\n\n"
  return result.latitude, result.longitude
end

def googleGeoCode(address, city, state, zip)
  lookupAddress =[address,city,state,zip].join(' ')
  debug 'Google Query Address: ' + lookupAddress
  uri = 'https://maps.googleapis.com/maps/api/geocode/json?address=' + lookupAddress
  uri = URI.parse(uri)

  sleep(0.5.seconds)
  res = Net::HTTP.get_response(uri)

  # debug res.code + res.message
  # debug res.body
  resBody = JSON.parse(res.body)

  if resBody['status'] == 'OVER_QUERY_LIMIT'
    puts "Hit Geocoding Limit"
    sleep(10.seconds)
    puts "RETRYING: " + address,city,state,zip
    googleGeoCode(address,city,state,zip)

  elsif res.code == 'ZERO_RESULTS'
    puts lookupAddress + " NOT FOUND"
  end

  debug "Response code: " + resBody['status']
  debug 'Google Query  Address : ' + lookupAddress
  debug 'Google Result Address : ' + resBody['results'].first['formatted_address'] + "\n\n"
  geocoded = resBody['results'].first['geometry']['location']

  return geocoded['lat'], geocoded['lng']
end

def parseFacility(hash)
  puts "Starting Facility Parse"
  facilitiesJSON =[]
  sitesServices = hash

  CSV.foreach($options[:fileName], encoding: "ISO-8859-1", headers: true, return_headers: false) do |row|

    site = sitesServices[row['AgencyID']][row['SiteID']]

    #move to next if the facility is already in the JSON
    next if facilitiesJSON.any?{|a| a[:agencyID] == row['AgencyID'] && a[:siteID] == row['SiteID']}

    services = []

    site['services'].each do |serviceID|
      debug [row['AgencyID'],row['SiteID'],serviceID].join('_')
      services << {__type: "Pointer", className: "Service", objectId: [row['AgencyID'],row['SiteID'],serviceID].join('_')}
    end

    if row['Name'].match(INT_WORD_RANGE)
      dirtyName = row['Name']
      cleanName = dirtyName.split.each_with_index.map do |word,index|
        case
        when word.match(A_HYPHEN)
          word
        when word.match(HYPHEN)
          word.titleize.gsub(' ', '-') if word.length > 1
        when word.match(THE)
          if index == 0
            word.titleize
          else
            word.downcase
          end
        when word.match(ABRV)
          word
        when !word.match(WORD_RANGE)
          word.titleize
        when word.match(WORD_RANGE)
          word.downcase
        end
      end.join(" ")
      name = cleanName
    else
      name = row['Name'].titleize
    end

    debug "FacilityName: #{name}"

    if row['Program Contact 2'].nil? and row['Contact 1 Phone']
      parsed_c1p = row['Contact 1 Phone'].match(PHONE_NUMBER)[0].to_s.strip
      phoneNumbers = [{info:"", number: parsed_c1p}]
    elsif !row['Program Contact 2'].nil?
      parsed_pc2 = row['Program Contact 2'].match(PHONE_NUMBER)[0].to_s.strip
      parsed_pc2_desc = row['Program Contact 2'].match(PHONE_NUM_DESC)
      debug "PAR: #{parsed_pc2_desc.inspect}"
      if !parsed_pc2_desc.nil?
        parsed_pc2_desc_trim = parsed_pc2_desc.to_s[1..-2]
        debug "PAT: #{parsed_pc2_desc_trim}"
      else
        parsed_pc2_desc_trim = ""
      end
      phoneNumbers = [{info:parsed_pc2_desc_trim, number: parsed_pc2}]
    else
      phoneNumbers = [{"info":"","number":""}]
    end

    debug "phoneNumbers: #{phoneNumbers.inspect}"

    if row["Web Site"].nil?
      website = ""
    elsif !row["Web Site"].nil?
      website = row["Web Site"]
      if !website.include? "http://"
        website = ["http://",website].join.to_s
      end
    end

    debug "Website: #{website.inspect}"

    if site["Gender"].uniq.length == 2
      gender = nil
    elsif site["Gender"].include? "Everyone"
      gender = nil
    elsif site["Gender"].uniq.include? "Male"
      gender = site["Gender"].uniq[0].chars.first
    elsif site["Gender"].uniq.include? "Female"
      gender = site["Gender"].uniq[0].chars.first
    end

    if site["Ages"].include? "Everyone"
      ages  = nil
    elsif !["Ages"].empty?
      ages = []
      ages_sort_order = ["C", "A", "S"]
      age_uniq = site["Ages"].uniq
      age_uniq.each do |a|
        case a
        when "Youth"
          ages << "C"
        when "Adults"
          ages << "A"
        when "Seniors"
          ages << "S"
        end
      end
      ages = ages.sort_by do |element|
        ages_sort_order.index(element)
      end
    end

    debug "Ages: #{ages.inspect}"

    location = {__type: "GeoPoint", latitude: site['location'][0], longitude: site['location'][1]}

    facilitiesJSON << {objectId: [row['AgencyID'],row['SiteID']].join('_'),
                       agencyID: row['AgencyID'],
                       siteID: row['SiteID'],
                       name: name,
                       categories: row['Category'].downcase,
                       address: row['Address 1'],
                       city: row['City'],
                       phoneNumbers: phoneNumbers,
                       website: website,
                       age: ages,
                       gender: gender,
                       location: location,
                       services: services}
    # "address","age","categories","city","gender","name","notes","objectId","phoneNumbers","services","website"
  end

  File.open('Facility.json', "w") do |f|
    f.puts JSON.pretty_generate({ "results": facilitiesJSON})
  end
  puts "Done with Facility Parse"
end


def parseService
  puts "Starting Service Parse"
  servicesJSON =[]

  CSV.foreach($options[:fileName], encoding: "ISO-8859-1", headers: true, return_headers: false) do |row|

    if !row['Program Name'].nil?
      name = row['Program Name']
      name = name.titleize if name == name.upcase
    else
      name = row['Service Group Name'].titleize
    end

    debug "Service: #{name}"

    #HOURS

    row["Parsed Program Hours"].nil? ? hours = row["Parsed Program Hours"] : hours = row["Parsed Program Hours"].strip

    if !hours.nil? and !hours.empty?
      debug "Row: #{$.}"
      debug hours.inspect
      hours = parse_hours(hours)
    elsif hours.nil? || hours.empty?
      hours = nil
    end
    debug hours.inspect

    # if !hours.nil?
    #   # puts hours.inspect
    #   hours.each do |d,t|
    #     hours[d].each do |t|
    #       if t[1] == 2359 and t[0] == 2359
    #         puts [row['AgencyID'],row['SiteID'],row['ServiceID']].join('_')
    #         puts hours.inspect
    #       end
    #     end
    #   end
    # end

    servicesJSON << {objectId: [row['AgencyID'],row['SiteID'],row['ServiceID']].join('_'),
                     agencyID: row['AgencyID'],
                     siteID: row['SiteID'],
                     serviceID: row['ServiceID'],
                     name: name,
                     category: row['Category'].downcase,
                     description: row['PROGRAM DESCRIPTION'],
                     notes: row['INTAKE PROCEDURE'],
                     eligibility: row['ELIGIBILITY'],
                     openHours: hours,
                     openHoursNotes: row['Notes Program Hours'],
                     facility: {__type: "Pointer", className: "Facility", objectId: [row['AgencyID'],row['SiteID']].join('_')}}
  end

  # {"category", "description", "facility": {"__type": "Pointer", "className": "Facility", "objectId": "poopeiasdlfadjf"}, "intake": "", "name", "notes", "objectId", "openHours": {"1": [[900, 1700 ] ], "2": [[900, 1700 ] ], "3": [[900, 1700 ] ], "4": [[900, 1700 ] ], "5": [[900, 1700 ] ]}}

  debug JSON.pretty_generate({ "results": servicesJSON})
  File.open('Service.json', "w") do |f|
    f.puts JSON.pretty_generate({ "results": servicesJSON})
  end
  puts "Done with Service Parse"
end

def debug(str)
  puts "\033[32m#{str}\033[0m" if $options[:verbose]
end

main if __FILE__==$0
