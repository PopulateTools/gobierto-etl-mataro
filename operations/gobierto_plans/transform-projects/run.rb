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
  val = src_attrs[name]
  return val if val.is_a?(String)

  src_attrs[name]&.first&.dig("nom") || "Indeterminat"
end

def string_custom_field(src_attrs, name)
  src_attrs[name]
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

  vals = SOURCE_PLANS_CONFIGURATIONS[plan_identifier][:vocabulary_custom_fields].each_with_object({}) do |k, hsh|
    hsh["custom_field_vocabulary_options_#{k.parameterize}"] = vocabulary_custom_field(src_attributes, k)
  end

  SOURCE_PLANS_CONFIGURATIONS[plan_identifier][:string_custom_fields].each_with_object(vals) do |k, hsh|
    hsh["custom_field_string_#{k.parameterize}"] = string_custom_field(src_attributes, k)
  end
end

def categories_vocabulary_terms(source_data, plan_identifier)
  source_data.select { |e| e["nivell"] != SOURCE_PLANS_CONFIGURATIONS[plan_identifier][:projects_level] && e["nivell"] != "1" }.map do |e|
    {
      "name_translations" => { "ca" => e["nom"], "en" => nil, "es" => nil },
      "slug" => "#{e["codi_tipus"]}-#{e["id"]}".parameterize,
      "parent_id" => e["id_parent"], "external_id" => e["id"]
    }
  end
end

def statuses_vocabulary_terms(source_data, _plan_identifier)
  base = source_data.map do |e|
    e["l_estats"].map { |x| x.slice("nom", "codi") }
  end.flatten.uniq

  base.map do |e|
    {
      "name_translations" => { "ca" => e["nom"], "en" => nil, "es" => nil },
      "slug" => e["codi"],
      "external_id" => e["codi"]
    }
  end
end

def request_body(projects_data, vocabularies_data = {})
  {
    "data" => {
      "attributes" => vocabularies_data.merge(
        "projects" => projects_data
      )
    }
  }.to_json
end

puts "[START] [#{plan_identifier}] transform-projects/run.rb with #{source_path} file"

raw_data = JSON.parse(File.read(source_path))

if (id = SOURCE_PLANS_CONFIGURATIONS[plan_identifier][:id]).present?
  raw_data = raw_data.select { |src_attrs| src_attrs["id_plan"] == id }
end

projects_data = filter_last_level_items(raw_data, plan_identifier).map { |src_attrs| transformed_project_attributes(src_attrs).merge(transformed_project_custom_fields(src_attrs, plan_identifier)) }
vocabularies_data = {
  "categories_vocabulary_terms" => categories_vocabulary_terms(raw_data, plan_identifier),
  "statuses_vocabulary_terms" => statuses_vocabulary_terms(raw_data, plan_identifier)
}

File.write(destination_path, request_body(projects_data, vocabularies_data))
puts "\tCreated transformed file #{destination_path}"

puts "[END] [#{plan_identifier}] transform-projects/run.rb"
