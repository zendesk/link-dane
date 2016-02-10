#!/usr/bin/env ruby

require 'json'
require 'csv'
require 'rails'
require 'geocoder'
require 'net/http'

def main
  data = createSiteHash()
  parseFacility(data) if ARGV[1] == "f"
  parseService() if ARGV[2] == "s"
end


def createSiteHash()
  sitesHash = Hash.new{|h,k| h[k]=Hash.new(&h.default_proc) }

  if ARGV[3] == 'g'
    puts "fetching fresh location data hold tight!"
    CSV.foreach(ARGV[0], encoding: "ISO-8859-1", headers: true, return_headers: false) do |row|
      site = sitesHash[row['AgencyID']][row['SiteID']]
      if site['services'].empty?
        site['services'] = Array.new
      end
      site['services'].push row['ServiceID']
      row['Address 1'].nil? ? site['address'] = "600-702 Braxton Place" : site['address'] = row['Address 1']
      row['City'].nil? ? site['city'] = "Madison" : site['city'] = row['City']
      row['Address 1'].nil? ? site['state'] = "WI" : site['state'] = row['State']
      row['Address 1'].nil? ? site['zipCode'] = "53715" : site['zipCode'] = row['ZIP Code']
      geoLat, geoLong = geoLookup(site['address'],site['city'],site['state'],site['zipCode'])
      site['location'] = Array.new()
      site['location'].push geoLat,geoLong
    end
    # puts sitesHash
    data = YAML.dump(sitesHash)
    open('sitesHash.yml', 'wb') { |f| f.puts data }
    puts "Done fetching location, check YML"
  else
    puts 'Using cached location'
    data=File.read("sitesHash.yml")
    sitesHashYAML = YAML.load(data)
    sitesHash = sitesHashYAML
    # puts sitesHashYAML
  end
  return sitesHash
end


def geoLookup(address, city, state, zip)
  lookupAddress =[address,city,state,zip].join(' ')
  # puts 'LOOKUP ' + lookupAddress
  uri = 'https://maps.googleapis.com/maps/api/geocode/json?address=' + lookupAddress
  uri = URI.parse(uri)

  sleep(0.5.seconds)
  res = Net::HTTP.get_response(uri)

  # puts res.code + res.message
  # puts res.body
  resBody = JSON.parse(res.body)

  if resBody['status'] == 'OVER_QUERY_LIMIT'
    puts "Hit Geocoding Limit"
    sleep(10.seconds)
    # puts "RETRY " + address,city,state,zip
    geoLookup(address,city,state,zip)

  elsif res.code == 'ZERO_RESULTS'
    puts lookupAddress + " NOT FOUND"
  end

  puts resBody['status']
  puts lookupAddress
  puts resBody['results'].first['formatted_address']
  geocoded = resBody['results'].first['geometry']['location']

  return geocoded['lat'], geocoded['lng']
end

def parseFacility(hash)
  facilitiesJSON =[]
  sitesServices = hash

  CSV.foreach(ARGV[0], encoding: "ISO-8859-1", headers: true, return_headers: false) do |row|

    site = sitesServices[row['AgencyID']][row['SiteID']]

    next if facilitiesJSON.any?{|a| a[:agencyID] == row['AgencyID'] && a[:siteID] == row['SiteID']}

    services = []
    site['services'].each do |serviceID|
      # puts [row['AgencyID'],row['SiteID'],serviceID].join('_')
      services << {__type: "Pointer", className: "Service", objectId: [row['AgencyID'],row['SiteID'],serviceID].join('_')}
    end

    unless row['Program Contact 2'].nil?
      phoneNumbers = [{info:"", number: row['Program Contact 2']}]
    else
      phoneNumbers = [{info:"", number: row['Contact 1 Phone']}]
    end

    location = {__type: "GeoPoint", latitude: site['location'][0], longitude: site['location'][1]}

    # "address","age","categories","city","gender","name","notes","objectId","phoneNumbers","services","website"
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
  end

  File.open('Facility.json', "w") do |f|
    f.puts JSON.pretty_generate({ "results": facilitiesJSON})
  end

end


def parseService
  servicesJSON =[]
  sitesServices = hash

  CSV.foreach(ARGV[0], encoding: "ISO-8859-1", headers: true, return_headers: false) do |row|

    # {"category", "description", "facility": {"__type": "Pointer", "className": "Facility", "objectId": "poopeiasdlfadjf"}, "intake": "", "name", "notes", "objectId", "openHours": {"1": [[900, 1700 ] ], "2": [[900, 1700 ] ], "3": [[900, 1700 ] ], "4": [[900, 1700 ] ], "5": [[900, 1700 ] ]}}

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

  # puts JSON.pretty_generate({ "results": servicesJSON})
  File.open('Service.json', "w") do |f|
    f.puts JSON.pretty_generate({ "results": servicesJSON})
  end

end

main if __FILE__==$0
