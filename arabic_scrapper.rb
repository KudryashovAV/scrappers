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
    @driver.get 'https://app.seamless-expo.com/event/seamless-middle-east-2024/people/RXZlbnRWaWV3XzY3MjA3OA=='

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
      email_input.send_keys("nir@krononsoft.com")

      email_submit_button = context.wait.until do
        context.driver.find_elements(xpath: "//*[contains(text(), 'Continue')]")
      end

      email_submit_button.last.click

      password_input = context.wait.until do
        context.driver.find_element(:css, "input#login-with-email-and-password-password-id")
      end
      password_input.send_keys("Mtbank_111")

      password_submit_button = context.wait.until do
        context.driver.find_elements(xpath: "//*[contains(text(), 'Continue')]")
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

      data = []
      while true do
        context.driver.execute_script("window.scrollTo(0, #{screen_height*x});")
        x += 1
        sleep(2)

        scroll_height = context.driver.execute_script("return document.body.scrollHeight;")

        if (screen_height) * x > scroll_height
          names_elements = context.wait.until do
            context.driver.find_elements(xpath: '//*[@id="__next"]/div[3]/div/main/div/div[2]/div/div/div/div')
          end

          links = names_elements.first.find_elements(:css, "a")

          puts "link elements #{links.count}"

          links.each do |link|
            info_hash = {}

            info_hash["link"] = link.attribute("href") || "no link"
            info_hash["full_name"] = link.find_elements(:xpath => "*").first.find_elements(:xpath => "*").first.find_elements(:css => "span.sc-a13c392f-0")[0]&.text || "no info"
            info_hash["position"] = link.find_elements(:xpath => "*").first.find_elements(:xpath => "*").first.find_elements(:css => "span.sc-a13c392f-0")[1]&.text || "no info"
            info_hash["firm"] = link.find_elements(:xpath => "*").first.find_elements(:xpath => "*").first.find_elements(:css => "span.sc-a13c392f-0")[2]&.text || "no info"

            data << info_hash unless info_hash.empty?
          end

          break
        end
      end

      CSV.open("all_data.csv", "ab", write_headers: true, headers: %w[Link, FullName, Position, Organization]) do |csv|
        data.each do |row|
          csv << row.values
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

        next if link == "Link,"

        context.driver.get(link)
        sleep 3
        personal_info = {}
        personal_info["link"] = link
        personal_info["name"] = context.driver.find_elements(xpath: '//*[@id="__next"]/div[3]/div/main/div[2]/div/div[2]/h2').first&.text || "no data"
        personal_info["position"] = context.driver.find_elements(xpath: '//*[@id="__next"]/div[3]/div/main/div[2]/div/div[2]/h4[1]').first&.text || "no data"
        personal_info["country"] = context.driver.find_elements(xpath: '//*[@id="__next"]/div[3]/div/main/div[2]/div/div[2]/h4[2]').first&.text || "no data"
        personal_info["firm"] = context.driver.find_elements(xpath: '//*[@id="__next"]/div[3]/div/main/div[2]/div/div[2]/h3').first&.text || "no data"
        personal_info["social"] = context.driver.find_elements(css: 'div.sc-9c9868a2-15.kzrhIj').first&.find_elements(:xpath => "*")&.map { |x| x.attribute("href") }&.join("########") || "no data"
        personal_info["contacts"] = context.driver.find_elements(css: 'div.sc-901e7a18-2.eEIcVK').first&.find_elements(:xpath => "*")&.map { |x| x.text }&.join("########") || "no data"
        collected_data << personal_info
      end

      CSV.open(file_name, "ab", write_headers: true, headers: %w[Link, FullName, Position, Country, Organization, Social, Contacts]) do |csv|
        collected_data.each do |row|
          csv << row.values
        end
      end
    end
  end

  organize AcceptCookies, Login, ScrollAndHarvest # 1 stage - get all users info
  # organize AcceptCookies, Login, HarvestPersonalData # 3 stage - get additional data from harvested and filtered data
end

# Run program
MlScraper.new.scrape


class CSVProcessor
  def self.call
    file_data = CSV.read("all_data.csv")

    founders_data = []
    ceo_data = []
    others_data = []

    file_data.each { |x| founders_data << x if x[2]&.match(/founder/i) }
    file_data.each { |x| ceo_data << x if x[2]&.match(/ceo/i) && !founders_data.include?(x) }
    file_data.each { |x| others_data << x if !ceo_data.include?(x) && !founders_data.include?(x) }

    CSV.open("founders.csv", "ab", write_headers: true, headers: %w[Link, FullName, Position, Organization]) do |csv|
      founders_data.uniq.each do |row|
        csv << row
      end
    end

    CSV.open("ceo.csv", "ab", write_headers: true, headers: %w[Link, FullName, Position, Organization]) do |csv|
      ceo_data.uniq.each do |row|

        csv << row
      end
    end

    CSV.open("others.csv", "ab", write_headers: true, headers: %w[Link, FullName, Position, Organization]) do |csv|
      others_data.uniq.each do |row|

        csv << row
      end
    end
  end
end

# CSVProcessor.call # 2 stage - filter data
