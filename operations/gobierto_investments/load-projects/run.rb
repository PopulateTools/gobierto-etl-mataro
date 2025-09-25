#!/usr/bin/env ruby

require "bundler/setup"
Bundler.require

require "http"

# Usage:
#
#  - Must be ran as an independent Ruby script
#
# Arguments:
#
#  - 0: Absolute path to a file containing the external ids of projects. There
#       is expected that there is a json file for each external id with the id
#       in the name
#  - 1: Path of transformed data for each project ready to be uploaded
#  - 2: API host
#
# Samples:
#
#   /path/to/project/operations/gobierto_investments/load-projects/run.rb  external_ids_file.txt transformed_path http://mataro.gobierto.test
#

if ARGV.length != 3
  raise "Review the arguments"
end

external_ids_file = ARGV[0]
transformed_path = ARGV[1]
api_host = ARGV[2]
bearer_header = "Bearer #{ENV.fetch("API_TOKEN")}"
projects_endpoint = "#{api_host}/gobierto_investments/api/v1/projects"

external_ids = File.open(external_ids_file).read.split(" ")

puts "[START] load-projects/run.rb with #{external_ids.count} file(s)"

external_ids.each do |id|
  data = JSON.parse(File.read(File.join(transformed_path, "#{id}.json")))

  puts "===================="
  resp = HTTP.auth(bearer_header).post(projects_endpoint, :json => data)
  sleep(2)
  if resp.status.success?
    puts "Project creation/update successful. API response:"
    puts JSON.parse(resp.body.to_s).inspect
  else
    raise StandardError, "Project creation/update failed. API response: #{JSON.parse(resp.body.to_s).inspect}"
  end
  puts "====================\n\n\n\n"
end

puts "[END] load-projects/run.rb"
