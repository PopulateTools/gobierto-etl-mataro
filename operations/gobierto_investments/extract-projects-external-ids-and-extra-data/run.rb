#!/usr/bin/env ruby

require "bundler/setup"
Bundler.require

# Usage:
#
#  - Must be ran as an independent Ruby script
#
# Arguments:
#
#  - 0: Absolute path to the input file
#  - 1: Absolute path to the output file with the list of ids to send
#       indivicual requests
#  - 2: Absoulte path to the output file with a json containing data of each
#       project not present in individual requests
#
# Samples:
#
#   /path/to/project/operations/gobierto_budgets/extract-projects-external-ids-and-extra-data/run.rb input.json external_ids.txt data.json
#

if ARGV.length != 3
  raise "Review the arguments"
end

input_file = ARGV[0]
output_ids_file = ARGV[1]
output_data_file = ARGV[2]

puts "[START] extract-projects-external-ids-and-extra-data/run.rb with input_file=#{input_file} output_ids_file=#{output_ids_file} and output_data_file=#{output_data_file}"

input = File.open(input_file).read
parsed_data = JSON.parse(input)["items"][0]["llistaobres2"]
ids = parsed_data.map { |item| item["id"] }

data = parsed_data.inject({}) do |hsh, item|
  hsh.update(
    item["id"] => item.slice("element", "import", "tipus", "tipus_projecte", "nom_servei_gestor")
  )
end

if File.dirname(output_ids_file) != "."
  FileUtils.mkdir_p(File.dirname(output_ids_file))
end

File.write(output_ids_file, ids.join(" "))

if File.dirname(output_data_file) != "."
  FileUtils.mkdir_p(File.dirname(output_data_file))
end

File.write(output_data_file, data.to_json)

puts "[END] extract-projects-external-ids-and-extra-data/run.rb"
