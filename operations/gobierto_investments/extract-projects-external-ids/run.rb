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
#  - 1: Absolute path to the output file
#
# Samples:
#
#   /path/to/project/operations/gobierto_budgets/extract-projects-external-ids/run.rb input.json output.json
#

if ARGV.length != 2
  raise "Review the arguments"
end

input_file = ARGV[0]
output_file = ARGV[1]

puts "[START] extract-projects-external-ids/run.rb with input_file=#{input_file} and output_file=#{output_file}"

input = File.open(input_file).read
ids = JSON.parse(input)["items"][0]["llistaobres2"].map{ |item| item["id"] }

if File.dirname(output_file) != "."
  FileUtils.mkdir_p(File.dirname(output_file))
end

File.write(output_file, ids.join(" "))

puts "[END] extract-project-external-ids/run.rb"
