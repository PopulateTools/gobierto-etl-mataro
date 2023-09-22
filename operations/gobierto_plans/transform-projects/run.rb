#!/usr/bin/env ruby

require "bundler/setup"
Bundler.require

# Usage:
#
#  - Must be ran as an independent Ruby script
#
# Arguments:
#
#  - 0: Absolute path to the source file wich is expected to contain a JSON
#  - 1: Absoulte estination path of transformed data destination
# Samples:
#
#   /path/to/project/operations/gobierto_plans/transform-projects/run.rb /tmp/mataro_plans/soruce.json /tmp/mataro_plans/transformed_data.json
#

if ARGV.length != 2
  raise "Review the arguments"
end

source_path = ARGV[0]
destination_path = ARGV[1]

def filter_last_level_items(source_data)
  source_data.select { |src_attrs| src_attrs["nivell"] == "6" }.reject do |src_attrs|
    # Reject projects with no status and progress 0
    src_attrs["l_estats"].first&.dig("codi").blank? && src_attrs["progres"] == "0"
  end
end

def status_external_id(src_attrs)
  src_attrs["l_estats"].first&.dig("codi") || "unknown"
end

def transformed_project_attributes(src_attrs)
  {
    "external_id" => src_attrs["id"],
    "visibility_level" => "published",
    "moderation_stage" => "approved",
    "name_translations" => { "ca" => src_attrs["nom"], "en" => nil, "es" => nil },
    "category_external_id" => src_attrs["id_parent"],
    "status_external_id" => status_external_id(src_attrs),
    "progress" => src_attrs["progres"].to_f
  }
end

def request_body(projects_data)
  {
    "data" => {
      "attributes" => {
        "projects" => projects_data
      }
    }
  }.to_json
end

puts "[START] transform-projects/run.rb with #{source_path} file"

raw_data = JSON.parse(File.read(source_path)).select{ |src_attrs| src_attrs["id_plan"] == 201872 }

projects_data = filter_last_level_items(raw_data).map { |src_attrs| transformed_project_attributes(src_attrs) }

File.write(destination_path, request_body(projects_data))
puts "\tCreated transformed file #{destination_path}"

puts "[END] transform-projects/run.rb"
