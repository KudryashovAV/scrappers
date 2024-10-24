require 'selenium-webdriver'
require 'interactor'
require 'byebug'
require 'csv'

class MlScraper
  def initialize
    # Initilize the driver with our desired browser
    @driver = Selenium::WebDriver.for :chrome

    # Define search string
    @search_str = 'carros 4x4 diesel'

    # Navigate to mercadolibre
    @driver.get 'https://app.seamless-expo.com/event/seamless-saudi-arabia-2024/people/RXZlbnRWaWV3XzY3MjEyMw=='

    # Define global timeout threshold, when @wait is called, if the program
    # takes more than 10 secs to return something, we'll infer that somethig
    # went wrong and execution will be terminated.
    @wait = Selenium::WebDriver::Wait.new(timeout: 10) # seconds
  end

  def scrape
    # Calling interactor that orchestrates the scraper's logic
    ScrapingOrganizer.call(
      driver: @driver,
      wait: @wait,
      search_str: @search_str
    )
    @driver.quit # Close browser when the task is completed
  end
end

class ScrapingOrganizer
  include Interactor::Organizer

  class ScrapingOrganizer::AcceptCookies
    include Interactor

    def call
      accept_cookies(context.driver, context.wait)
    end

    private

    def accept_cookies(driver, wait)
      submit_button = wait.until do
        driver.find_elements(xpath: "//*[contains(text(), 'Accept all')]")
      end
      submit_button.last.click
    end
  end

  class ScrapingOrganizer::Login
    include Interactor

    def call
      login_button = context.wait.until do
        context.driver.find_elements(xpath: "//*[contains(text(), 'Log in')]")
      end
      login_button.first.click

      email_input = context.wait.until do
        context.driver.find_element(:css, "input#lookup-email-input-id")
      end
      email_input.send_keys("kudryashov.alexey.v@gmail.com")

      email_submit_button = context.wait.until do
        context.driver.find_elements(xpath: "//*[contains(text(), 'Continue')]")
      end

      email_submit_button.last.click

      password_input = context.wait.until do
        context.driver.find_element(:css, "input#login-with-email-and-password-password-id")
      end
      password_input.send_keys("TapZykfoTapZykfo1")

      # //*[@id="login-form"]/button/span
      password_submit_button = context.wait.until do
        context.driver.find_elements(xpath: "//*[contains(text(), 'Log in')]")
      end

      password_submit_button.last.click

      sleep 8
    end
  end

  class ScrapingOrganizer::ScrollAndHarvest
    include Interactor

    def call
      screen_height = context.driver.execute_script("return window.screen.height;")

      x = 1

      global_data = []
      while true do
        data = []
        context.driver.execute_script("window.scrollTo(0, #{screen_height*x});")
        x += 1
        sleep(2)

        scroll_height = context.driver.execute_script("return document.body.scrollHeight;")

        names_elements = context.wait.until do
          context.driver.find_elements(class: "infinite-scroll-component")
        end

        links = names_elements.first.find_elements(:css, "a")

        puts "Iteration #{x}"

        links.each do |link|
          info_hash = {}
          info_hash["link"] = link.attribute("href") || "no link"
          info_hash["info"] = link.text.gsub("\n", " ") || "no info"

          data << info_hash unless info_hash.empty?
          global_data << info_hash unless info_hash.empty?
        end

        puts "global count #{global_data.count}"

        CSV.open("all_data.csv", "ab") do |csv|
          data.each do |row|
            csv << row.values
          end
        end

        if screen_height * x > scroll_height
          break
        end
      end
    end
  end

  class ScrapingOrganizer::HarvestPersonalData
    include Interactor

    def call
      ceo_harvester(context)
      founders_harvester(context)
    end

    private

    def ceo_harvester(context)
      harvester(context, CSV.read("ceo.csv"), "collected_ceo_data.csv")
    end

    def founders_harvester(context)
      harvester(context, CSV.read("founders.csv"), "collected_founders_data.csv")
    end

    def harvester(context, data, file_name)
      collected_data = []
      data.each do |data|
        link = data.first

        next if link == "Link"

        context.driver.get(link)
        sleep 3

        personal_info = {}
        personal_info["link"] = link
        personal_info["name"] = context.driver.find_elements(class: 'sc-f3b80a80-1').first&.text || "no data"
        personal_info["position"] = context.driver.find_elements(xpath: '/html/body/div[2]/div[3]/div/main/div[2]/div/div[1]/h4[1]').first&.text || "no data"
        personal_info["country"] = context.driver.find_elements(xpath: '/html/body/div[2]/div[3]/div/main/div[2]/div/div[1]/h4[2]').first&.text || "no data"
        personal_info["firm"] = context.driver.find_elements(xpath: '/html/body/div[2]/div[3]/div/main/div[2]/div/div[1]/h3').first&.text || "no data"
        personal_info["social"] = context.driver.find_elements(xpath: '/html/body/div[2]/div[3]/div/main/div[2]/div/div[15]').first&.find_elements(:xpath => "*")&.map { |x| x.attribute("href") }&.compact&.join("########") || "no data"
        personal_info["contacts"] = context.driver.find_elements(css: 'div.sc-901e7a18-2.eEIcVK').first&.find_elements(:xpath => "*")&.map { |x| x.text }&.compact&.join("########") || "no data"
        collected_data << personal_info if personal_info["social"] != "no data" || personal_info["contacts"] != "no data"
      end

      CSV.open(file_name, "ab", write_headers: true, headers: %w[Link, FullName, Position, Country, Organization, Social, Contacts]) do |csv|
        collected_data.each do |row|
          csv << row.values
        end
      end
    end
  end

  # organize AcceptCookies, Login, ScrollAndHarvest # 1 stage - get all users info
  organize AcceptCookies, Login, HarvestPersonalData # 3 stage - get additional data from harvested and filtered data
end

# Run program
MlScraper.new.scrape


class CSVProcessor
  def self.call
    # file_data = CSV.read("all_data.csv")
    puts "Start to read at #{Time.now}"
    file_data = []
    CSV.foreach("all_data.csv", :headers => true) do |row|
      file_data << row
    end

    founders_data = []
    ceo_data = []
    others_data = []

    count = 0

    file_data.each do |row|
      count += 1
      puts "Total: #{file_data.count} / Processed: #{count} / Left: #{file_data.count - count}"
      founders_data << row.to_h if row[1]&.match(/founder/i)
      ceo_data << row.to_h if row[1]&.match(/ceo/i) && !row[1]&.match(/founder/i)
      others_data << row if !row[1]&.match(/ceo/i) && !row[1]&.match(/founder/i)
    end

    puts "Finish to read at #{Time.now}"
    puts "Start to write read at #{Time.now}"

    CSV.open("founders.csv", "ab", write_headers: true, headers: %w[Link Info]) do |csv|
      founders_data.uniq.each do |row|
        csv << row
      end
    end

    CSV.open("ceo.csv", "ab", write_headers: true, headers: %w[Link Info]) do |csv|
      ceo_data.uniq.each do |row|

        csv << row
      end
    end

    CSV.open("others.csv", "ab", write_headers: true, headers: %w[Link Info]) do |csv|
      others_data.uniq.each do |row|

        csv << row
      end
    end
    puts "Finish to write at #{Time.now}"
  end
end

# CSVProcessor.call # 2 stage - filter data
