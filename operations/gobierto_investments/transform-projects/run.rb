#!/usr/bin/env ruby

require "http"
require "bundler/setup"
Bundler.require

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
#  - 2: Json file returned by the gobierto API for a new project
#  - 3: Path of data for each project
#  - 4: Destination path of transformed data
#  - 5: API host
#  - 6: Id of the collection to which the files to be attached will belong
# Samples:
#
#   /path/to/project/operations/gobierto_budgets/transform-projects/run.rb external_ids_file.txt meta_file.json new_file.json data_path transformed_path http://mataro.gobierto.test 2026
#

if ARGV.length != 7
  raise "Review the arguments"
end

external_ids_file = ARGV[0]
meta_file = ARGV[1]
new_file = ARGV[2]
data_path = ARGV[3]
transformed_path = ARGV[4]
api_host = ARGV[5]
attachments_collection_id = ARGV[6]
bearer_header = "Bearer #{ENV.fetch("API_TOKEN")}"
attachments_endpoint = "#{api_host}/admin/attachments/api/attachments"

if File.join(transformed_path, "/") != "./"
  FileUtils.mkdir_p(File.join(transformed_path, "/"))
end

external_ids = File.open(external_ids_file).read.split(" ")
meta = File.open(meta_file).read
new_json = File.open(new_file).read

puts "[START] transform-projects/run.rb with #{external_ids.count} file(s)"

detailed_data = external_ids.inject({}) do |accumulated, id|
  detailed_content = File.open(File.join(data_path, "#{id}.json")).read
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

def meta(key)
  data = @meta_data.dig("data").find{ |e| e.dig("attributes", "uid") == key.to_s }
  OpenStruct.new(data.dig("attributes"))
end

def vocabulary(key)
  meta(key).vocabulary_terms
end

@cf_keys = [
  "estat",
  "descripcio-projecte",
  "data-inici",
  "nom-servei-responsable",
  "tipus-projecte",
  "nom-projecte",
  "notes",
  "data-adjudicacio",
  "import-liquidacio",
  "wkt",
  "tasques",
  "data-final",
  "data-inici-redaccio",
  "adjudicatari",
  "adreca",
  "import",
  "import-adjudicacio",
  "data-fi-redaccio"
]

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
  "imagenes" => "imagenes-i-documents"
}

@meta_data = JSON.parse(meta).with_indifferent_access

detailed_data.each do |k, v|
  content = v["items"][0]["detallobre2"][0]

  new_hash = JSON.parse(new_json)

  @cf_keys.each do |cf_k|
    meta_data = meta(cf_k)
    val = get_value(content, cf_k)
    value = if meta_data.field_type == "vocabulary_options"
              vocabulary = vocabulary(cf_k)
              if vocabulary(cf_k).find{ |e| e.dig("name_translations", "ca") == val || e.dig("name") == val }.blank?
                raise StandardError, "Name #{val} is not present in vocabulary for #{cf_k} custom field"
              end
              (vocabulary(cf_k).find{ |e| e.dig("name_translations", "ca") == val || e.dig("name") == val } || {})["id"]
            elsif meta_data.field_type == "localized_string"
              { ca: val }
            elsif meta_data.field_type == "date"
              val.present? ? Date.parse(val).to_s : val
            else
              val
            end
    new_hash["data"]["attributes"][cf_k] = value
    if cf_k == "nom-projecte"
      new_hash["data"]["attributes"]["title_translations"] = value
    end
  end

  # Images
  images = []
  processed_images = []
  ["imagen_principal", "imagenes_i_documents", "imagenes"].each do |image_key|
    raw_images = content[image_key]
    processed_images = []
    if raw_images.present?
      raw_images.each do |raw_image_data|
        resp = HTTP.auth(bearer_header).post(attachments_endpoint, :json => attachment_body(raw_image_data, attachments_collection_id))
        if resp.status.success?
          body = JSON.parse(resp.body.to_s)
          processed_images << body.dig("attachment", "url")
          raise StandardError, "File uploaded, but no attachment url has been returned" if body.dig("attachment", "url").blank?
        else
          raise StandardError, "File upload failed"
        end
      end
    end
    images.concat processed_images
  end

  new_hash["data"]["attributes"]["external_id"] = k
  new_hash["data"]["attributes"]["gallery"] = images

  File.write(File.join(transformed_path, "#{k}.json"), new_hash.to_json)
  puts "\tCreated transformed file #{k}.json"
end

puts "[END] transform-projects/run.rb"
