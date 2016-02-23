require_relative "parseHours"

CSV.foreach("masterHours.csv", encoding: "ISO-8859-1", headers: true, return_headers: false) do |row|
	puts $.
	puts row[1]
	openHours = parse_hours(row[1])
	puts openHours.inspect
end