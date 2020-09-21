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
#  - 1: API host
#
# Samples:
#
#   /path/to/project/operations/gobierto_investments/delete-projects/run.rb  external_ids_file.txt http://mataro.gobierto.test
#

if ARGV.length != 2
  raise "Review the arguments"
end

external_ids_file = ARGV[0]
api_host = ARGV[1]
bearer_header = "Bearer #{ENV.fetch("API_TOKEN")}"
projects_endpoint = "#{api_host}/gobierto_investments/api/v1/projects"
project_endpoint = ->(project_id) { "#{api_host}/gobierto_investments/api/v1/projects/#{project_id}" }

external_ids = File.open(external_ids_file).read.split(" ")

puts "[START] delete-projects/run.rb with #{external_ids.count} file(s)"

existing_projects = JSON.parse(HTTP.auth(bearer_header).get(projects_endpoint)).fetch("data", [])

missing_existing_projects = existing_projects.inject({}) do |projects, project|
  next projects if external_ids.include?(project.dig("attributes", "external_id"))

  projects.update(
    project.dig("attributes", "external_id") => project["id"]
  )
end

missing_existing_projects.each do |external_id, id|
  puts "===================="
  resp = HTTP.auth(bearer_header).delete(project_endpoint.call(id))
  if resp.status.success?
    puts "Project with external id #{external_id} and id #{id} deletion successful."
  else
    raise StandardError, "Project with external id #{external_id} and id #{id} deletion failed. API response: #{resp.body}"
  end
  puts "====================\n\n\n\n"
end

puts "[END] delete-projects/run.rb"
