#!/usr/bin/env ruby

require "bundler/setup"
Bundler.require

require "http"

# Usage:
#
#  - Must be ran as an independent Ruby script
#
# Arguments:
#
#  - 0: Absolute path to a file containing the external ids of projects. There
#       is expected that there is a json file for each external id with the id
#       in the name
#  - 1: Json file returned by the gobierto API for the meta action, containing
#       information about fields
#  - 2: Json file containing extra data of projects obtained from other source
#       which has to be loaded
#  - 3: Json file returned by the gobierto API for a new project
#  - 4: Path of data for each project
#  - 5: Destination path of transformed data
#  - 6: API host
#  - 7: Id of the collection to which the files to be attached will belong
# Samples:
#
#   /path/to/project/operations/gobierto_budgets/transform-projects/run.rb external_ids_file.txt meta_file.json projects_extra_data.json new_file.json data_path transformed_path http://mataro.gobierto.test 2026
#

if ARGV.length != 8
  raise "Review the arguments"
end

external_ids_file = ARGV[0]
meta_file = ARGV[1]
projects_extra_data_file = ARGV[2]
new_file = ARGV[3]
data_path = ARGV[4]
transformed_path = ARGV[5]
api_host = ARGV[6]

new_api = /_new\.txt\z/.match?(external_ids_file)

attachments_opts = {
  attachments_collection_id: ARGV[7],
  bearer_header: "Bearer #{ENV.fetch("API_TOKEN")}",
  attachments_endpoint: "#{api_host}/admin/attachments/api/attachments",
  terms_endpoint: ->(vocabulary_id) {"#{api_host}/admin/api/vocabularies/#{vocabulary_id}/terms"}
}

TRANSFORMATION_RULES = {
  "estat" => { "-" => "Creat" },
  "wkt" => { "POINT( )" => NilClass }
}.freeze

if File.join(transformed_path, "/") != "./"
  FileUtils.mkdir_p(File.join(transformed_path, "/"))
end

external_ids = File.open(external_ids_file).read.split(" ")
meta = File.open(meta_file).read
new_json = File.open(new_file).read
projects_extra_data = JSON.parse(File.open(projects_extra_data_file).read)

puts "[START] transform-projects/run.rb with #{external_ids.count} file(s)"

detailed_data = external_ids.inject({}) do |accumulated, id|
  filename = new_api ? "#{id}-new.json" : "#{id}.json"
  detailed_content = File.open(File.join(data_path, filename)).read
  accumulated.update(
    id => JSON.parse(detailed_content)
  )
end

def attachment_body(data, attachments_collection_id)
  {
    "attachment": {
      "file_name": data["filename"],
      "collection_id": attachments_collection_id,
      "description": { id: data["id"], "code": data["codi"] }.to_json,
      "name": data["nom"],
      "file": data["content"].tr("\r\n", "")
    }
  }
end

def get_value(content, key)
  if @keys_translations.find{ |_, v| v == key}.blank?
    raise StandardError, "Custom field #{key} is missing in origin data definition."
  end
  content_key = @keys_translations.find{ |_, v| v == key}[0]
  content[content_key]
end

def apply_transformation_rule(value, key)
  transformed_value = TRANSFORMATION_RULES.dig(key, value)

  return value if transformed_value.blank?
  return nil if transformed_value == NilClass

  transformed_value
end

def meta(key)
  data = @meta_data.dig("data").find{ |e| e.dig("attributes", "uid") == key.to_s }
  OpenStruct.new(data.dig("attributes"))
end

def vocabulary(key)
  meta(key).vocabulary_terms
end

def vocabulary_id(key)
  meta(key).options.dig("vocabulary_id")
end

def process_multiple_terms(vocabulary_id, destination_terms, custom_field_key, value, attachments_opts)
  return [] if value.blank?

  terms_ids = value.map do |source_term|
    detect_term_id_from_vocabulary(source_term, vocabulary_id, destination_terms, custom_field_key, attachments_opts)
  end
end

def process_single_term(vocabulary_id, destination_terms, custom_field_key, value, attachments_opts)
  value = value.to_s if value.present?
  keys_sequences = [%w(name_translations ca), %w(name)]

  destination_term = destination_terms.find do |term|
    keys_sequences.any? { |seq| nested_key_exists?(term, *seq) && term.dig(*seq) == value }
  end

  return if destination_term.blank? && value.blank?

  if destination_term.blank?
    new_term_id = create_term(vocabulary_id, attachments_opts.merge(term: { name_translations: { ca: value } }))
    puts "Name #{value} is not present in vocabulary for #{custom_field_key} custom field. New term created or get from the API"
    new_term_id
  else
    destination_term["id"]
  end
end

def process_table(configuration, terms, cf_k, value, attachments_opts)
  value = transform_table_source(cf_k, value)
  return value if configuration["columns"].blank? || value.blank?

  columns_configs = configuration["columns"].each_with_object({}) do |data, config|
    if data["type"] == "vocabulary"
      data["vocabulary_id"] = data["dataSource"]&.match(/\d+\z/)&.[](1) || configuration["vocabulary_ids"]&.first
    end
    config[data["id"]] = data
  end
  columns_ids = columns_configs.keys

  value.map do |row|
    direct_values = row.slice(*columns_ids)

    direct_values.each_with_object({}) do |(k,v), transformed_row|
      conf = columns_configs[k]

      transformed_row[k] = case conf["type"]
                           when "vocabulary"
                             detect_term_id_from_vocabulary(v, conf["vocabulary_id"], terms, cf_k, attachments_opts)
                          when "date"
                            v.present? ? Date.parse(v).to_s : v
                           else
                             v
                           end
    end
  end
end

def detect_term_id_from_vocabulary(source_term, vocabulary_id, destination_terms, custom_field_key, attachments_opts)
  return source_term["nom"] if vocabulary_id.blank?

  external_id = source_term["id"]
  text = source_term["nom"]
  text = text.to_s if text.present?

  destination_term = destination_terms.find { |term| term["external_id"] == external_id }
  if destination_term.blank?
    new_term_id = create_term(vocabulary_id, attachments_opts.merge(term: { name_translations: { ca: text }, external_id: }))
    puts "Name #{text} is not present in vocabulary for #{custom_field_key} custom field. New term created or obtained from the API"
    new_term_id
  else
    destination_term["id"]
  end
end

def transform_table_source(cf_k, value)
  case cf_k
  when "estats"
    value = value.sort_by { |row| row["codi"] }
    value.map do |row|
      term_id = row.delete("codi")
      row["nom"] = { "id" => term_id, "nom" => row["nom"] }
      row
    end
  else
    value
  end
end

def process_attachments_of(content, opts = {})
  keys = opts.fetch(:keys, [])
  with_metadata = opts.fetch(:with_metadata, false)

  processed_files = []

  keys.inject([]) do |processed_files, attachment_key|
    raw_files = content[attachment_key]&.reject { |file_data| file_data["content"].blank? }

    next processed_files if raw_files.blank?

    processed_files + raw_files.map do |raw_file_data|
      resp = HTTP.auth(opts[:bearer_header]).post(opts[:attachments_endpoint], :json => attachment_body(raw_file_data, opts[:attachments_collection_id]))
      sleep(2)
      if resp.status.success?
        body = JSON.parse(resp.body.to_s)
        raise StandardError, "File uploaded, but no attachment url has been returned" if (url =  body.dig("attachment", "url")).blank?
        with_metadata ? body.dig("attachment").slice("file_name", "url", "human_readable_url", "file_size").merge(raw_file_data.slice("nom")) : url
      else
        raise StandardError, "File upload failed"
      end
    end
  end
end

def create_term(vocabulary_id, opts)
  resp = HTTP.auth(opts[:bearer_header]).post(opts[:terms_endpoint].call(vocabulary_id), :json => opts.slice(:term))
  sleep(2)
  if resp.status.success?
    body = JSON.parse(resp.body.to_s)
    body["id"]
  else
    raise StandardError, "Term creation failed"
  end
end

def nested_key_exists?(hash, *keys)
  keys.reduce(hash) do |h, key|
    return false unless h.is_a?(Hash) && h.key?(key)

    h[key]
  end
  true
end

@cf_keys = JSON.parse(meta)["data"].map{|e| e["attributes"]["uid"]} - %w(gallery documents budget tipus-projecte-tipus-concatenation)
@keys_translations = {
  "id" => "external_id",
  "descripcio_projecte" => "descripcio-projecte",
  "imagen_principal" => "imagen-principal",
  "tipus_projecte" => "tipus-projecte",
  "nom_projecte" => "nom-projecte",
  "import_licitacio" => "import",
  "import_liquidacio" => "import-liquidacio",
  "import_adjudicacio" => "import-adjudicacio",
  "imagenes_i_documents" => "imagenes-i-documents",
  "tasques" => "tasques",
  "wkt" => "wkt",
  "nom_servei_responsable" => "nom-servei-responsable",
  "estat" => "estat",
  "data_inici" => "data-inici",
  "data_fin" => "data-fin",
  "data_adjudicacio" => "data-adjudicacio",
  "data_inici_redaccio" => "data-inici-redaccio",
  "data_fi_redaccio" => "data-fi-redaccio",
  "adjudicatari" => "adjudicatari",
  "data_final" => "data-final",
  "adreca" => "adreca",
  "notes" => "notes",
  "documents" => "documents",
  "imagenes" => "imagenes-i-documents",
  "partida" => "partida",
  "any_partida" => "any-partida",
  "any_estat" => "any-estat",
  "element" => "element",
  "nom_servei_gestor" => "nom-servei-gestor",
  "tipus" => "tipus",
  "import" => "import-main",
  "financament" => "financament",
  "data_aprovacio" => "data-aprovacio",
  "data_inici_obra" => "data-inici-obra",
  "data_final_obra" => "data-final-obra",
  "zones" => "zones",
  "consells_territorials" => "consells-territorials",
  "any_pla_inversions" => "any-pla-inversions",
  "estats" => "estats",
  "import_adjudicacio_ambiva" => "import-adjudicacio-ambiva",
  "import_licitacio_ambiva" => "import-licitacio-ambiva",
  "import_liquidacio_ambiva" => "import-liquidacio-ambiva"
}

@meta_data = JSON.parse(meta).with_indifferent_access

new_keys = []

detailed_data.each do |k, v|
  detail_key = new_api ? "detallobrainv" : "detallobre2"
  content = v["items"][0][detail_key][0].merge(projects_extra_data[k.to_s])

  new_keys = new_keys | (content.keys - @keys_translations.keys)
  new_hash = JSON.parse(new_json)

  @cf_keys.each do |cf_k|
    meta_data = meta(cf_k)
    val = get_value(content, cf_k)
    val = apply_transformation_rule(val, cf_k)
    value = case meta_data.field_type
            when "vocabulary_options"
              v_terms = vocabulary(cf_k)
              v_id = vocabulary_id(cf_k)
              if meta_data.options.dig("configuration", "vocabulary_type") == "multiple_select"
                process_multiple_terms(v_id, v_terms, cf_k, val, attachments_opts).map(&:to_s)
              else
                process_single_term(v_id, v_terms, cf_k, val, attachments_opts)
              end
            when "localized_string"
              { ca: val }
            when "date"
              val.present? ? Date.parse(val).to_s : val
            when "plugin"
              if meta_data.options.dig("configuration", "plugin_type") == "table"
                v_terms = vocabulary(cf_k)
                configuration = meta(cf_k).options.dig("configuration", "plugin_configuration")
                process_table(configuration, v_terms, cf_k, val, attachments_opts)
              else
                val
              end
            else
              val
            end
    new_hash["data"]["attributes"][cf_k] = value
    if cf_k == "nom-projecte"
      new_hash["data"]["attributes"]["title_translations"] = value
    end
  end

  new_hash["data"]["attributes"]["external_id"] = content["codi"]
  new_hash["data"]["attributes"]["gallery"] = process_attachments_of(content, attachments_opts.merge(keys: ["imagen_principal", "imagenes_i_documents", "imagenes"]))
  new_hash["data"]["attributes"]["documents"] = process_attachments_of(content, attachments_opts.merge(keys: ["documents"], with_metadata: true))
  new_hash["data"]["attributes"]["tipus-projecte-tipus-concatenation"] = { ca:  %w(tipus-projecte tipus).map { |e| get_value(content, e)}.join(" - ") }

  File.write(File.join(transformed_path, "#{k}.json"), new_hash.to_json)
  puts "\tCreated transformed file #{k}.json"
end

if new_keys.present?
  puts "There are new unrecognized_keys: #{new_keys.map(&:inspect).join(", ")}"
end

puts "[END] transform-projects/run.rb"
