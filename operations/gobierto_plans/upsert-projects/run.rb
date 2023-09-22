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
#  - 0: Absolute path to the file containing the JSON body to send to the endpoint
#  - 1: API plan endpoint t
# Samples:
#
#   /path/to/project/operations/gobierto_plans/upsert-projects/run.rb body_file.json api_endpoint
#

if ARGV.length != 2
  raise "Review the arguments"
end

body_file_path = ARGV[0]
api_endpoint = ARGV[1]
bearer_header = "Bearer #{ENV.fetch("API_TOKEN")}"

body = File.open(body_file_path).read

puts "[START] upsert-projects/run.rb with #{body_file_path} file"

resp = HTTP.auth(bearer_header).put(api_endpoint, json: JSON.parse(body))

if resp.status.success?
  body = JSON.parse(resp.body.to_s)
  puts "\tPlan with #{body.dig("data", "attributes", "projects")&.count.to_i} processes updated"
else
  raise StandardError, "Upsert failed"
end

puts "[END] upsert-projects/run.rb"
