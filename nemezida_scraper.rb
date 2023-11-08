require 'nokogiri'
require 'http'
require 'csv'
require 'byebug'
require "down"

# first step - scrape data from each available pages

# def scraper_each_page
#   pages = { "https://nemezida.com/first/page/" => 476,
#             "https://nemezida.ru/second/page/" => 215,
#             "https://nemezida.ru/third/page/" => 10,
#             "https://nemezida.ru/fourth/page/" => 8,
#             "https://nemezida.ru/fifth/page/" => 1,
#             "https://nemezida.ru/sixth/page/" => 3 }
#
#   dictionary = []
#
#   pages.each_pair do |url, count|
#     (2..count).to_a.each do |page_number|
#       uuu = url + page_number.to_s + "/"
#
#       unparsed_page = HTTP.get(uuu).to_s
#
#       parsed_page = Nokogiri::HTML(unparsed_page)
#
#       parsed_page.css('h3.simple-grid-grid-post-title').each do |element|
#         element.css('a').each do |el|
#           dictionary << [el.children.text, el.values.first]
#         end
#       end
#     end
#   end
#
#   pages.each_pair do |url, _|
#     uuu = url.gsub("page/", "")
#
#     unparsed_page = HTTP.get(uuu).to_s
#
#     parsed_page = Nokogiri::HTML(unparsed_page)
#
#     parsed_page.css('h3.simple-grid-grid-post-title').each do |element|
#       element.css('a').each do |el|
#         dictionary << [el.children.text, el.values.first]
#       end
#     end
#   end
#
#
#   CSV.open("nemezida.csv", "w") do |csv|
#     dictionary.each do |arr|
#       csv << [arr.first, arr.last]
#     end
#   end
# end
#
# scraper_each_page
#


# second step - create folder with data for each person

# def create_folder_with_data
#   system('mkdir', '-p', "results")
#   File.new('full_data.csv', 'w')
#   start_time = Time.now
#
#   puts "#"*100
#   puts start_time
#   puts "#"*100
#
#   CSV.open("full_data.csv", "w") do |csv|
#     CSV.foreach("nemezida.csv") do |name_pair|
#       system('mkdir', '-p', "results/#{name_pair.first.gsub(" ", "")}")
#       file_name = "results/#{name_pair.first.gsub(" ", "")}/#{name_pair.first.gsub(" ", "")}.txt"
#       File.new(file_name, 'w')
#       sleep 3
#       unparsed_page = HTTP.get(name_pair.last).to_s
#
#       parsed_page = Nokogiri::HTML(unparsed_page)
#
#       data = parsed_page.css('div.entry-content.simple-grid-clearfix').text.split("\r\n").map(&:lstrip).delete_if(&:empty?)
#
#       data.unshift("Name: #{name_pair.first}")
#       data << "Date: #{parsed_page.css('span.simple-grid-entry-meta-single-date').text.gsub("\r\n", "").lstrip}"
#       data << "Department: #{parsed_page.css('span.simple-grid-entry-meta-single-cats').text}"
#
#       data << "Image: #{parsed_page.css('div.photos_single_place').first.css('a').map{|x| x.values.first}.join(', ')}"
#
#       image_urls = parsed_page.css('div.photos_single_place').first.css('a').map { |x| x.css('img').first['data-src'] }.uniq
#
#       image_urls.each_with_index do |url, index|
#         # image_name = File.new("results/#{name_pair.first.gsub(" ", "")}/#{name_pair.first.partition(" ").first}#{index.to_s}.jpg", 'w')
#         Down.download(url, destination: "results/#{name_pair.first.gsub(" ", "")}/")
#       end
#
#       File.open(file_name, "w+") do |f|
#         data.each { |element| f.puts(element) }
#       end
#
#       puts "@@@@@@@@@@@@@@@@"
#       puts name_pair.first
#       puts Time.at(Time.now - start_time)
#       puts "@@@@@@@@@@@@@@@@"
#
#       csv << data
#
#     rescue StandardError => e
#       puts "@"*1000
#       puts e
#       puts "@"*1000
#       next
#
#
#     end
#   end
#   puts "#"*100
#   puts Time.at(Time.now - start_time)
#   puts "#"*100
#
#   # image_urls.each_with_index do |url, index|
#   #   File.open("#{name_pair.first}/#{name_pair.first.partition(" ").first}#{index.to_s}.jpg", "wb") do |f|
#   #     debugger
#   #     f.write(open(url).read)
#   #   end
#   # end
#   #
#   #
#   # File.open(file_name, "w+") do |f|
#   #   data.each { |element| f.puts(element) }
#   # end
# end

def create_folder_with_sbu_data
  system('mkdir', '-p', "results")
  File.new('full_data.csv', 'w')
  start_time = Time.now

  puts "#"*100
  puts start_time
  puts "#"*100

  CSV.open("full_data.csv", "w") do |csv|
    CSV.foreach("sbu.csv") do |name_pair|
      system('mkdir', '-p', "results/sbu/#{name_pair.first.gsub(" ", "")}")
      file_name = "results/sbu/#{name_pair.first.gsub(" ", "")}/#{name_pair.first.gsub(" ", "")}.txt"
      File.new(file_name, 'w')
      sleep 3
      unparsed_page = HTTP.get(name_pair.last).to_s

      parsed_page = Nokogiri::HTML(unparsed_page)

      data = parsed_page.css('div.entry-content.simple-grid-clearfix').text.split("\r\n").map(&:lstrip).delete_if(&:empty?)

      data.unshift("Name: #{name_pair.first}")
      data << "Date: #{parsed_page.css('span.simple-grid-entry-meta-single-date').text.gsub("\r\n", "").lstrip}"
      data << "Department: #{parsed_page.css('span.simple-grid-entry-meta-single-cats').text}"

      data << "Image: #{parsed_page.css('div.photos_single_place').first.css('a').map{|x| x.values.first}.join(', ')}"

      image_urls = parsed_page.css('div.photos_single_place').first.css('a').map { |x| x.css('img').first['data-src'] }.uniq

      image_urls.each_with_index do |url, index|
        # image_name = File.new("results/#{name_pair.first.gsub(" ", "")}/#{name_pair.first.partition(" ").first}#{index.to_s}.jpg", 'w')
        Down.download(url, destination: "results/sbu/#{name_pair.first.gsub(" ", "")}/")
      end

      File.open(file_name, "w+") do |f|
        data.each { |element| f.puts(element) }
      end

      puts "@@@@@@@@@@@@@@@@"
      puts name_pair.first
      puts Time.at(Time.now - start_time)
      puts "@@@@@@@@@@@@@@@@"

      csv << data

    rescue StandardError => e
      puts "@"*1000
      puts e
      puts "@"*1000
      next
    end
  end
  puts "#"*100
  puts Time.at(Time.now - start_time)
  puts "#"*100

  # image_urls.each_with_index do |url, index|
  #   File.open("#{name_pair.first}/#{name_pair.first.partition(" ").first}#{index.to_s}.jpg", "wb") do |f|
  #     debugger
  #     f.write(open(url).read)
  #   end
  # end
  #
  #
  # File.open(file_name, "w+") do |f|
  #   data.each { |element| f.puts(element) }
  # end
end

create_folder_with_sbu_data
