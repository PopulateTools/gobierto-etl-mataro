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
#  - 1: Absoulte path of transformed data destination
#  - 2: Identifier of the plan to include personalizations like the projects level
# Samples:
#
#   /path/to/project/operations/gobierto_plans/transform-projects/run.rb /tmp/mataro_plans/soruce.json /tmp/mataro_plans/transformed_data.json PAM
#

if ARGV.length != 3
  raise "Review the arguments"
end

source_path = ARGV[0]
destination_path = ARGV[1]
plan_identifier = ARGV[2]

SOURCE_PLANS_CONFIGURATIONS = {
  "PAM" => { projects_level: "7", id: 177592, vocabulary_custom_fields: %w(l_valoracions) },
  "urban_agenda_2030" => { projects_level: "4" }
}

def filter_last_level_items(source_data, plan_identifier)
  source_data.select { |src_attrs| src_attrs["nivell"] == SOURCE_PLANS_CONFIGURATIONS[plan_identifier][:projects_level] }.reject do |src_attrs|
    # Reject projects with no status and progress 0
    src_attrs["l_estats"].first&.dig("codi").blank? && src_attrs["progres"] == "0"
  end
end

def status_external_id(src_attrs)
  src_attrs["l_estats"].first&.dig("codi") || "unknown"
end

def vocabulary_custom_field(src_attrs, name)
  src_attrs[name]&.first&.dig("nom") || "Indeterminat"
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

def transformed_project_custom_fields(src_attributes, plan_identifier)
  return {} if SOURCE_PLANS_CONFIGURATIONS[plan_identifier][:vocabulary_custom_fields].blank?

  SOURCE_PLANS_CONFIGURATIONS[plan_identifier][:vocabulary_custom_fields].each_with_object({}) do |k, hsh|
    hsh["custom_field_vocabulary_options_#{k}"] = vocabulary_custom_field(src_attributes, k)
  end
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

puts "[START] [#{plan_identifier}] transform-projects/run.rb with #{source_path} file"

raw_data = JSON.parse(File.read(source_path))

if (id = SOURCE_PLANS_CONFIGURATIONS[plan_identifier][:id]).present?
  raw_data = raw_data.select { |src_attrs| src_attrs["id_plan"] == id }
end

projects_data = filter_last_level_items(raw_data, plan_identifier).map { |src_attrs| transformed_project_attributes(src_attrs).merge(transformed_project_custom_fields(src_attrs, plan_identifier)) }

File.write(destination_path, request_body(projects_data))
puts "\tCreated transformed file #{destination_path}"

puts "[END] [#{plan_identifier}] transform-projects/run.rb"
