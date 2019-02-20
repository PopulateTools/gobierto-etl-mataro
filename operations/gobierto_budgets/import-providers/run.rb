#!/usr/bin/env ruby

require "bundler/setup"
Bundler.require

# Usage:
#
#  - Must be ran as an independent Ruby script
#
# Arguments:
#
#  - 0: Organization ID
#  - 1: Absolute path to a file containing a CSV of providers
#
# Samples:
#
#   /path/to/project/operations/gobierto_budgets/import-providers/run.rb 8019 input.csv
#

if ARGV.length != 2
  raise "At least one argument is required"
end

index = GobiertoData::GobiertoBudgets::ES_INDEX_POPULATE_DATA_PROVIDERS
type =  GobiertoData::GobiertoBudgets::POPULATE_DATA_PROVIDERS_TYPE

organization_id = ARGV[0].to_s
data_file = ARGV[1]
index_request_body = []

def parse_mataro_data(raw_date)
  return nil if raw_date.blank?
  day, month, year = raw_date.split('-')
  month = case month.strip
          when 'GEN.' then 1
          when 'JAN' then 1
          when 'FEBR.' then 2
          when 'FEB' then 2
          when 'MARÇ' then 3
          when 'MAR' then 3
          when 'ABR.' then 4
          when 'APR' then 4
          when 'MAIG' then 5
          when 'MAY' then 5
          when 'JUNY' then 6
          when 'JUN' then 6
          when 'JUL.' then 7
          when 'JUL' then 7
          when 'AG.' then 8
          when 'AUG' then 8
          when 'SET.' then 9
          when 'SEP' then 9
          when 'OCT.' then 10
          when 'OCT' then 10
          when 'NOV.' then 11
          when 'NOV' then 11
          when 'DES.' then 12
          when 'DEC' then 12
          end
  return Date.new(year.to_i, month, day.to_i)
rescue
  puts "Error parsing date"
  puts raw_date
end


place = INE::Places::Place.find(organization_id)
base_attributes = if place
                    {
                      location_id: place.id,
                      province_id: place.province.id,
                      autonomous_region_id: place.province.autonomous_region.id
                    }
                  else
                    { location_id: organization_id, province_id: nil, autonomous_region_id: nil }
                  end

puts "[START] import-providers/run.rb data_file=#{data_file}"

nitems = 0
CSV.foreach(data_file, headers: true) do |row|
  date = parse_mataro_data(row['DATA_FRA'])
  next if date.nil?
  attributes = base_attributes.merge({
    value: row['IMPORT'].tr(',', '.').to_f,
    date: date.strftime("%Y-%m-%d"),
    invoice_id: SecureRandom.uuid,
    provider_id: row['NIF_PROV'].try(:strip),
    provider_name: row['NOM_PROV'].try(:strip),
    payment_date: nil,
    paid: row['ESTAT_FRA'].downcase.strip == 'pagada',
    subject: row['CONCEPTE_FRA'].try(:strip),
    freelance: row['NIF_PROV'] !~ /\A[A-Z]/i,
    economic_budget_line_code: nil,
    functional_budget_line_code: nil
  })

  nitems += 1
  id = [attributes[:location_id], date.year, attributes[:invoice_id]].join('/')
  index_request_body << {index: {_id: id, data: attributes}}
  if nitems % 10 == 0
    GobiertoData::GobiertoBudgets::SearchEngineWriting.client.bulk index: index, type: type, body: index_request_body
    index_request_body = []
  end
end


puts "[END] import-providers/run.rb imported #{nitems} items"
