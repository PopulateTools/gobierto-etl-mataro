#!/usr/bin/env ruby

require "bundler/setup"
Bundler.require
require "csv"

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
#   /path/to/project/operations/gobierto_budgets/clean-quotes/run.rb input.csv output.csv
#

if ARGV.length != 2
  raise "Review the arguments"
end

input_file = ARGV[0]
output_file = ARGV[1]

puts "[START] clean-quotes/run.rb with file=#{input_file}"

content = File.open(input_file).read
content.gsub!(/"Observatori desenv. eco. local"/, 'Observatori desenv. eco. local')
content.gsub!(/"Festa al Cel"/, 'Festa al Cel')
content.gsub!(/"Suport al servei menjador EB"/, 'Suport al servei menjador EB')
content.gsub!(/"Promoció de la ciutat"/, 'Promoció de la ciutat')
content.gsub!(/"La promoció de la ciutat i el comerç"/, 'La promoció de la ciutat i el comerç')
File.open(output_file, 'wb+').write(content)

puts "[END] clean-quotes/run.rb"
