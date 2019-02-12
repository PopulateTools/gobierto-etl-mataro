#!/usr/bin/env ruby

require "bundler/setup"
Bundler.require

require "csv"
require "json"

# Usage:
#
#  - Must be ran as an independent Ruby script
#
# Arguments:
#
#  - 0: Absolute path to a file containing a CSV
#  - 2: Domain of the site
#
# Samples:
#
#   operations/gobierto_budgets/extract-custom-categories/run.rb input.csv mataro.gobierto.es
#

if ARGV.length != 2
  raise "At least one argument is required"
end

input_file = ARGV[0]
domain = ARGV[1]

site = Site.find_by! domain: domain
area_name = 'custom'

puts "[START] extract-custom-categories/run.rb with file=#{input_file} domain=#{site.domain}"

CSV.read(input_file, headers: true).each do |row|
  next if row['IMPASSIG'].blank?

  if row['TIPPARTIDA'].strip == 'Despeses'
    kind = GobiertoData::GobiertoBudgets::EXPENSE
  elsif row['TIPPARTIDA'].strip == 'Ingressos'
    kind = GobiertoData::GobiertoBudgets::INCOME
  end

  level_2_category = row['PROGRAMA']
  level_3_category = row['SUBPROGRAMA']
  level_4_category = row['PRJNOM']

  [level_2_category, level_3_category, level_4_category].each do |raw_name|
    next if raw_name !~ /\A[\d\-]+\-/
    begin
      code = raw_name.match(/\A[\d\-]+\-/)[0][0..-2]
      name = raw_name.match(/\A[\d\-]+\-(.+)/)[1]
    rescue
      puts raw_name
      exit
    end
    if category = GobiertoBudgets::Category.where(site: site, area_name: area_name, kind: kind, code: code).first
      category.custom_name_translations = {"ca" => name, "es" => name}
      category.save
      puts "- Updated category #{name} (code = #{code}, kind = #{kind})"
    else
      category = GobiertoBudgets::Category.new(site: site, area_name: area_name, kind: kind, code: code)
      category.custom_name_translations = {"ca" => name, "es" => name}
      category.save!
      puts "- Created category #{name} (code = #{code}, kind = #{kind})"
    end
  end
end

puts "[END] extract-custom-categories/run.rb with file=#{input_file} domain=#{site.domain}"
