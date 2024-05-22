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

SITE = Site.find_by! domain: domain
AREA_NAME = "custom"
$already_updated = {
  GobiertoBudgetsData::GobiertoBudgets::EXPENSE => [],
  GobiertoBudgetsData::GobiertoBudgets::INCOME => []
}

puts "[START] extract-custom-categories/run.rb with file=#{input_file} domain=#{SITE.domain}"

def create_or_update_category!(name, code, kind)
  name_translations = { "ca" => name, "es" => name }
  category_attrs = { site: SITE, area_name: AREA_NAME, kind: kind, code: code }

  return if $already_updated[kind].include?(code)

  if (category = GobiertoBudgets::Category.where(category_attrs).first)
    category.update!(custom_name_translations: name_translations)
    puts "- Updated category #{name} (code = #{code}, kind = #{kind})"
  else
    GobiertoBudgets::Category.create!(
      category_attrs.merge(custom_name_translations: name_translations)
    )
    puts "- Created category #{name} (code = #{code}, kind = #{kind})"
  end

  $already_updated[kind] << code
end

FIRST_LEVEL_CUSTOM_CATEGORIES.each do |category_name, category_code|
  GobiertoBudgetsData::GobiertoBudgets::ALL_KINDS.each do |kind|
    create_or_update_category!(category_name, category_code, kind)
  end
end

CSV.read(input_file, headers: true).each do |row|
  if row['TIPPARTIDA'].strip == 'Despeses'
    kind = GobiertoBudgetsData::GobiertoBudgets::EXPENSE
  elsif row['TIPPARTIDA'].strip == 'Ingressos'
    kind = GobiertoBudgetsData::GobiertoBudgets::INCOME
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

    create_or_update_category!(name, code, kind)
  end
end

puts "[END] extract-custom-categories/run.rb with file=#{input_file} domain=#{SITE.domain}"
