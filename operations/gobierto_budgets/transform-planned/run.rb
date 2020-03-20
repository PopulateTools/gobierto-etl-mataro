#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
Bundler.require

require_relative "../common/custom_categories"

require "csv"
require "json"

# Usage:
#
#  - Must be ran as an independent Ruby script
#
# Arguments:
#
#  - 0: Absolute path to a file containing a CSV
#  - 1: Absolute path of the output file
#  - 2: Year of the data
#
# Samples:
#
#   /path/to/project/operations/gobierto_budgets/transform-planned/run.rb input.csv output.json 2010
#

if ARGV.length != 3
  raise "At least one argument is required"
end

input_file = ARGV[0]
output_file = ARGV[1]
year = ARGV[2].to_i

puts "[START] transform-planned/run.rb with file=#{input_file} output=#{output_file} year=#{year}"

place = INE::Places::Place.find_by_slug('mataro')
population = GobiertoData::GobiertoBudgets::Population.get(place.id, year) || GobiertoData::GobiertoBudgets::Population.get(place.id, year - 1)

base_data = {
  organization_id: place.id,
  ine_code: place.id.to_i,
  province_id: place.province.id.to_i,
  autonomy_id: place.province.autonomous_region.id.to_i,
  year: year,
  population: population
}

output_data = []

def parse_amount(row, year)
  cell_value = (year == 2020) ? row["IMPASSIG_V4"] : row["IMPASSIG_V1"]

  cell_value.tr(",", ".").to_f
end

def parse_cell(row, year, name)
  return if year == 2020 && row["IMPASSIG_V4"].blank? || !row["CODIACUM"].blank?
  return if year != 2020 && row["IMPASSIG_V1"].blank?
  return if row[name].blank?

  category_name = row[name].strip

  if row['TIPPARTIDA'].strip == 'Despeses'
    kind = GobiertoData::GobiertoBudgets::EXPENSE
  elsif row['TIPPARTIDA'].strip == 'Ingressos'
    kind = GobiertoData::GobiertoBudgets::INCOME
  end
  re = /\A([I\d\-]+)\-(.+)\z/
  if category_name !~ re
    category_code = FIRST_LEVEL_CUSTOM_CATEGORIES[category_name].to_s
  else
    category_name.match(re)
    category_code = $1.strip
    category_name = $2.try(:strip)
  end
  if category_code.nil? || category_name.nil?
    raise "Invalid row: #{name} - #{category_name}"
  end

  if category_code.to_s.length == 4
    parent_category_name = row['PARCLSFUN_GRP'].strip
    @parent_categories[category_code] = FIRST_LEVEL_CUSTOM_CATEGORIES[parent_category_name]
  end

  @categories[kind][category_code] ||= 0
  @categories[kind][category_code] += parse_amount(row, year)
  @categories[kind][category_code] = @categories[kind][category_code].round(2)

  # Extract economic information from PARCAPITOL
  if name != 'PARCAPITOL'
    row['PARCAPITOL'].match(/\A(\d+)\-(.*)\z/)
    economic_category_code = $1.strip
    @economic_categories[kind][category_code] ||= {}
    @economic_categories[kind][category_code][economic_category_code] ||= 0
    @economic_categories[kind][category_code][economic_category_code] += parse_amount(row, year)
  end
end

## Custom

type = GobiertoData::GobiertoBudgets::CUSTOM_AREA_NAME

@parent_categories = {}
@categories = { GobiertoData::GobiertoBudgets::INCOME => {}, GobiertoData::GobiertoBudgets::EXPENSE => {} }
@economic_categories = { GobiertoData::GobiertoBudgets::INCOME => {}, GobiertoData::GobiertoBudgets::EXPENSE => {} }

CSV.read(input_file, headers: true).each do |row|
  parse_cell(row, year, 'PROGRAMA')
  parse_cell(row, year, 'SUBPROGRAMA')
  parse_cell(row, year, 'PRJNOM')
  parse_cell(row, year, 'PARCLSFUN_GRP')
end


# level 1: 1-23
# level 2: I003-Ingressos genèrics (prog)
# level 3: I0031-Ingressos genèrics (subprog)
# level 4: 0111105-001-Planificació financera

@categories.keys.each do |kind|
  @categories[kind].each do |code, amount|

    case code.length
    when 1,2,3
      level = 1
      parent_code = nil
    when 4
      level = 2
      parent_code = @parent_categories[code]
    when 5
      level = 3
      parent_code = code[0..-2]
    else
      level = 4
      parent_code = code[0..4]
    end

    output_data.push base_data.merge({
      amount: amount.to_f.round(2),
      code: code,
      level: level,
      kind: kind,
      amount_per_inhabitant: (amount.to_f / population).round(2),
      parent_code: parent_code,
      type: type
    })
  end
rescue TypeError => e
  puts "\n[ERROR] Can't find population data. Is it loaded in ElasticSearch #{ENV['ELASTICSEARCH_URL']}?\n" if population.nil?
  raise e
end

## Economic categories inside custom categories

@categories.keys.each do |kind|
  @categories[kind].each do |code, _|
    @economic_categories[kind][code].each do |economic_code, amount|
      output_data.push base_data.merge({
        amount: amount.to_f.round(2),
        code: economic_code,
        custom_code: code,
        level: 1,
        kind: kind,
        amount_per_inhabitant: (amount.to_f / population).round(2),
        parent_code: nil,
        type: "economic-#{type}"
      })
    end
  end
end

## Economic

type = GobiertoData::GobiertoBudgets::ECONOMIC_AREA_NAME

@categories = { GobiertoData::GobiertoBudgets::INCOME => {}, GobiertoData::GobiertoBudgets::EXPENSE => {} }

CSV.read(input_file, headers: true).each do |row|
  parse_cell(row, year, 'PARCAPITOL')
  parse_cell(row, year, 'PARCLSECO_2D')
  parse_cell(row, year, 'PARCLSECO_3D')
  parse_cell(row, year, 'PARCLSECO')
end

@categories.keys.each do |kind|
  @categories[kind].each do |code, amount|

    level = code.length
    next if level > 5
    if level == 5
      parent_code = code[0...3]
      code = "#{parent_code}-#{code[3..4]}"
    else
      parent_code = code[0..-2]
    end

    next if @categories[kind].select{|l| l.starts_with?(parent_code) && l != parent_code && l != code }.empty?
    next if amount == 0

    output_data.push base_data.merge({
      amount: amount.to_f.round(2),
      code: code,
      level: level,
      kind: kind,
      amount_per_inhabitant: (amount.to_f / population).round(2),
      parent_code: parent_code,
      type: type
    })
  end
end

## Functional

type = GobiertoData::GobiertoBudgets::FUNCTIONAL_AREA_NAME

@categories = { GobiertoData::GobiertoBudgets::INCOME => {}, GobiertoData::GobiertoBudgets::EXPENSE => {} }
@economic_categories = { GobiertoData::GobiertoBudgets::INCOME => {}, GobiertoData::GobiertoBudgets::EXPENSE => {} }


CSV.read(input_file, headers: true).each do |row|
  parse_cell(row, year, 'PARCLSFUN_1D')
  parse_cell(row, year, 'PARCLSFUN_2D')
  parse_cell(row, year, 'PARCLSFUN')
end

kind = GobiertoData::GobiertoBudgets::EXPENSE
@categories[kind].each do |code, amount|
  level = code.length
  next if level > 5
  if level == 5
    parent_code = code[0...3]
    code = "#{parent_code}-#{code[3..4]}"
  else
    parent_code = code[0..-2]
  end

  next if @categories[kind].select{|l| l.starts_with?(parent_code) && l != parent_code && l != code }.empty?
  next if amount == 0

  output_data.push base_data.merge({
    amount: amount.to_f.round(2),
    code: code,
    level: level,
    kind: kind,
    amount_per_inhabitant: (amount.to_f / population).round(2),
    parent_code: parent_code,
    type: type
  })
end

@categories.keys.each do |kind|
  @categories[kind].each do |code, _|
    @economic_categories[kind][code].each do |economic_code, amount|
      output_data.push base_data.merge({
        amount: amount.to_f.round(2),
        code: economic_code,
        functional_code: code,
        level: 1,
        kind: kind,
        amount_per_inhabitant: (amount.to_f / population).round(2),
        parent_code: nil,
        type: "economic-#{type}"
      })
    end
  end
end

File.write(output_file, output_data.to_json)

puts "[END] transform-planned/run.rb output=#{output_file}"
