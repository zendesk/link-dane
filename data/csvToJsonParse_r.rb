#!/usr/bin/env ruby

require 'json'
require 'csv'
require 'rails'
require 'geocoder'
require 'net/http'
require 'optparse'

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

  raise OptionParser::MissingArgument if $options[:entityToParse].nil?
  raise OptionParser::MissingArgument if $options[:geocode].nil?

rescue OptionParser::MissingArgument
  puts "Incorrect argument for and option. Please check help"
  exit 1

rescue OptionParser::ParseError
  puts "Having trouble parsing options provided. Please check help"
  exit 1

else
  Geocoder.configure(:mapbox => {:dataset => "mapbox.places-permanent", :api_key => "pk.eyJ1IjoiejNucGNoaGV0cmkiLCJhIjoiY2lrZzdtb3lhMDA1NHZwbHkzeGJzNng1bCJ9.HDiB75xbQ7MT8tQsiSaBwg"})
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
  end

  debug "The siteHash without geocode: \n #{sitesHash}"

  debug "Starting to geocode!"

  if $options[:geocode] != :mc and $options[:geocode] != :gc
    puts "Geocoding, this may take some time. Please be patient (especially if using Google)\n\n"

    sitesHash.each do |agencyID, siteID|
      siteID.each do |k,v|
        # debug "#{v}"
        geoLat, geoLong = googleGeoCode(v['address'],v['city'],v['state'],v['zipCode']) if $options[:geocode] == :g
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
  puts "Staring Facility Parse"
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

    unless row['Program Contact 2'].nil?
      phoneNumbers = [{info:"", number: row['Program Contact 2']}]
    else
      phoneNumbers = [{info:"", number: row['Contact 1 Phone']}]
    end

    location = {__type: "GeoPoint", latitude: site['location'][0], longitude: site['location'][1]}

    facilitiesJSON << {objectId: [row['AgencyID'],row['SiteID']].join('_'),
                       agencyID: row['AgencyID'],
                       siteID: row['SiteID'],
                       name: (row['Name']).titleize,
                       categories: row['Category'].downcase,
                       address: row['Address 1'],
                       city: row['City'],
                       phoneNumbers: phoneNumbers,
                       website: row["Web Site"],
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
  puts "Staring Service Parse"
  servicesJSON =[]

  CSV.foreach($options[:fileName], encoding: "ISO-8859-1", headers: true, return_headers: false) do |row|


    servicesJSON << {objectId: [row['AgencyID'],row['SiteID'],row['ServiceID']].join('_'),
                     agencyID: row['AgencyID'],
                     siteID: row['SiteID'],
                     serviceID: row['ServiceID'],
                     name: (row['Service Group Name']).titleize,
                     category: row['Category'].downcase,
                     description: row['PROGRAM DESCRIPTION'],
                     notes: row['INTAKE PROCEDURE'],
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
