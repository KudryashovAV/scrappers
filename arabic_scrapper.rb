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
    @driver.get 'https://app.seamless-expo.com/event/seamless-middle-east-2024/people/RXZlbnRWaWV3XzY3MjA3OA==?filters=RmllbGREZWZpbml0aW9uXzY3OTY5OA%253D%253D%3ARmllbGRWYWx1ZV8yMjkyODcwMA%253D%253D%2CRmllbGRWYWx1ZV8yMjkyODU0Mw%253D%253D%2CRmllbGRWYWx1ZV8yMjkyODUzOA%253D%253D%3BRmllbGREZWZpbml0aW9uXzY3OTcwNg%253D%253D%3ARmllbGRWYWx1ZV8yMjkyODU0Mg%253D%253D%2CRmllbGRWYWx1ZV8yMjkyODU0Ng%253D%253D%2CRmllbGRWYWx1ZV8yMjkyODU3OQ%253D%253D%3BRmllbGREZWZpbml0aW9uXzM5ODkzOA%253D%253D%3ARmllbGRWYWx1ZV8xNzg1MDE5OQ%253D%253D%2CRmllbGRWYWx1ZV8xNzg1MDIyNw%253D%253D%2CRmllbGRWYWx1ZV8xNzg1MDI1OA%253D%253D%2CRmllbGRWYWx1ZV8xNzg1MDI3Mw%253D%253D%3BRmllbGREZWZpbml0aW9uXzY3OTcwNA%253D%253D%3ARmllbGRWYWx1ZV8yMjkyODUzNg%253D%253D%2CRmllbGRWYWx1ZV8yMjkyODUzOQ%253D%253D'

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

      CSV.open("aaa.csv", "ab", write_headers: true, headers: %w[Link, FullName, Position, Organization]) do |csv|
        data.each do |row|
          csv << row.values
        end
      end
    end
  end

  organize AcceptCookies, Login
end

# Run program
# MlScraper.new.scrape


class CSVProcessor
  def self.call
    file_data = CSV.read("aaa.csv")

    founders_data = []
    ceo_data = []

    file_data.each { |x| founders_data << x if x[2]&.match(/founder/i) }
    file_data.each { |x| ceo_data << x if x[2]&.match(/ceo/i) && !founders_data.include?(x) }

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
  end
end


CSVProcessor.call
