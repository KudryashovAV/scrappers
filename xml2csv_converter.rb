require "byebug"
require "crack"
require "json"
require "csv"

class Aaa
  def self.call
    xml_doc  = Crack::XML.parse(File.read("products.xml"))
    string_doc = xml_doc.to_json
    products = JSON.parse(string_doc)
    puts products["products"]["product"].count
    CSV.open("products.csv", "ab", write_headers: true, headers: %w[id product_id product_type group_sku variation_type product_sku upc_ean brand name retail_price wholesale_price description main_picture picture1 picture2 picture3 picture4 picture5 gender category subcategory size quantity color material product_code origin size_slug description_plain weight location currency date_modified_gmt active condition]) do |csv|
      count = 0
      products["products"]["product"].each do |row|
        puts count
        csv << [row["id"], row["product_id"], row["product_type"], row["group_sku"], row["variation_type"], row["product_sku"], row["upc_ean"], row["brand"], row["name"], row["retail_price"], row["wholesale_price"], row["description"], row["main_picture"], row["picture1"], row["picture2"], row["picture3"], row["picture4"], row["picture5"], row["gender"], row["category"], row["subcategory"], row["size"], row["quantity"], row["color"], row["material"], row["product_code"], row["origin"], row["size_slug"], row["description_plain"], row["weight"], row["location"], row["currency"], row["date_modified_gmt"], row["active"], row["condition"]]
        count += 1
      end
    end
  end
end

Aaa.call

