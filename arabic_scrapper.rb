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
    @driver.get 'https://app.seamless-expo.com/c/seamless-2/people/RXZlbnRWaWV3XzYzMzMzMA=='

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

      old_elements = []

      while true do
        context.driver.execute_script("window.scrollTo(0, #{screen_height*x});")
        x += 1
        sleep(2)

        scroll_height = context.driver.execute_script("return document.body.scrollHeight;")

        break if (screen_height) * x > scroll_height
        names_elements = context.wait.until do
          context.driver.find_elements(xpath: "//*[contains(@class, 'container__List')]")
        end

        pp "names_elements"
        pp names_elements.first.find_elements(:css, "a").count

        # byebug

        diff = names_elements.first.find_elements(:css, "a").difference(old_elements)

        unless diff.empty?
          array = []
          diff.each do |info_element|
            info_hash = {}

            info_element.find_elements(:css, "a").each do |element|
              info_hash["link"] = element.attribute("href") || "no link"
            end

            info_element.find_elements(:css, "span").each do |span|
              if span.attribute("class").match("FullName")
                info_hash["full_name"] = span.text || "no info"
              elsif span.attribute("class").match("_Job-")
                info_hash["job"] = span.text || "no info"
              elsif span.attribute("class").match("Organization")
                info_hash["organization"] = span.text || "no info"
              end
            end

            array << info_hash unless info_hash.empty?
          end

          if old_elements.empty?
            CSV.open("aaa.csv", "ab", write_headers: true, headers: %w[Link, FullName, Job, Organization]) do |csv|
              array.each do |row|
                csv << row.values
              end
            end
          else
            CSV.open("aaa.csv", "ab") do |csv|
              array.each do |row|
                csv << row.values
              end
            end
          end
        end

        old_elements = old_elements + diff

        pp "diff.count"
        pp diff.count

        pp "old_elements.count"
        pp old_elements.count
      end
    end
  end

  class ScrapingOrganizer::GetTitles
    include Interactor

    def call
      # Executes block while the next button is visible
      # If it's not it means that we are already on the last page
      while nxt_button_visible?(context.wait, context.driver) do
        print_titles(context.driver, context.wait) # Prints titles from current page
        nxt_button(context.driver).click # Goes to next page
      end
    end

    private

    # Finds the next button
    def nxt_button(driver)
      driver.find_element(:css, 'li.andes-pagination__button.andes-pagination__button--next')
    end

    # displayed? tells us if the element is present in the DOM
    def nxt_button_visible?(wait, driver)
      wait.until { nxt_button(driver).displayed? }
    end

    def print_titles(driver, wait)
      # Finds the titles displayed in the current page
      titles = wait.until do
        driver.find_elements(:css, '.main-title')
      end

      # Prints the element's text
      titles.map { |title| puts title.text }
    end
  end

  organize AcceptCookies, Login, GetTitles
end



# Run program
MlScraper.new.scrape
