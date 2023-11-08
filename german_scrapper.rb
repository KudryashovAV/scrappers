require "selenium-webdriver"
require "interactor"
require "byebug"
require "csv"
require "nokogiri"
require "http"

class MlScraper
  def initialize
    # Initilize the driver with our desired browser
    @driver = Selenium::WebDriver.for :chrome

    # Define search string
    @search_str = "carros 4x4 diesel"

    # Navigate to mercadolibre
    @driver.get "https://vfm-makler.de/suche/"  #"https://vfm-makler.de/suche/"

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
        driver.find_elements(xpath: "//*[contains(text(), 'Alle akzeptieren')]")  #"cm-btn cm-btn-success cm-btn-accept-all"
      end
      submit_button.last.click
    end
  end

  class ScrapingOrganizer::WorkingProcess
    include Interactor

    def call
      search_by_zip("71364")
      companies_data = get_all_companies_data
      get_all_employees_data(companies_data)
    end

    private

    def search_by_zip(zip_code)
      zip_input = context.wait.until do
        context.driver.find_elements(:xpath, "//*[@id='c7924']/div/form/div[3]/div/input")
      end
      zip_input.last.send_keys(zip_code)

      search_button = context.wait.until do
        context.driver.find_elements(:xpath, "//*[@id='c7924']/div/form/div[3]/div/span/button")
      end
      search_button.last.click
    end


    def get_all_companies_data
      collected_data = {}
      company_elements = context.wait.until do
        context.driver.find_elements(xpath: "//*[contains(@class, 'col-lg-9')]")
      end
      company_elements.each do |element|

        href = element.find_elements(:css, "h2").first.find_elements(:css, "a").first.attribute(:href)
        current_data = { broker_pool: "vfm" }

        data = element.text.split("\n")

        started_index = data.find_index("So finden Sie uns")
        zip, city = data[started_index + 2].split(" ")

        current_data[:broker] = data[0]
        current_data[:zip] = zip
        current_data[:city] = city
        current_data[:street] = data[started_index + 1]
        current_data[:phone] = data.find{|x| x.include?("Telefon")}&.gsub("Telefon ", "")
        current_data[:fax] = data.find{|x| x.include?("Telefax")}&.gsub("Telefax ", "")
        current_data[:sex] = "no data"
        current_data[:website] = data.find{|x| x.include?("Website")}&.gsub("Website ", "")
        current_data[:general_email] = data.find{|x| x.include?("E-Mail")}&.gsub("E-Mail ", "")

        collected_data[href] = current_data
      end
      collected_data
    end

    def get_all_employees_data(companies_data)
      collected_data = []

      about_us_prefix = "ueber-uns/"

      companies_data.each do |url, company_data|
        # next unless company_data[:broker] == "VMW GMBH"

        unparsed_page = HTTP.get(url + about_us_prefix).to_s
        parsed_page = Nokogiri::HTML(unparsed_page)
        employee_elements = parsed_page.css('div.row.row-cols-1.row-cols-md-2.row-cols-xl-3.row-cols-xxl-4').first.children

        employee_elements.each do |element|
          employee_data = company_data
          element.css('div.member').children.each do |employee|
            next if employee.children.first.name == "img"
            employee_data[:user_full_name] = employee.text.gsub("\n", "") if employee.classes.include?("name")
            employee_data[:user_positions] = employee_data[:user_positions] || ""
            employee_data[:user_positions] = employee_data[:user_positions] + ", " + employee.text.gsub("\n", "") if employee.name == "p" && employee.children.first.name == "text" && !employee.text.empty?

            if employee.name == "p" && employee.children.first.name == "span"
              employee.children.each do |x|
                employee_data[:user_phone] = x.text.gsub("\n", "") if x.classes.include?("phone")
                employee_data[:user_fax] = x.text.gsub("\n", "") if x.classes.include?("fax")
                employee_data[:user_email] = x.text.gsub("\n", "") if x.classes.include?("email")
              end
            end
          end
          collected_data << [
            employee_data[:broker_pool],
            employee_data[:broker],
            employee_data[:zip],
            employee_data[:city],
            employee_data[:street],
            employee_data[:phone],
            employee_data[:fax],
            employee_data[:sex],
            employee_data[:user_full_name],
            employee_data[:user_positions].gsub(/^,\s/, ""),
            employee_data[:user_email],
            employee_data[:user_phone],
            employee_data[:user_fax],
            employee_data[:website],
            employee_data[:general_email],
          ]
        end

      end

      # byebug
      CSV.open("vfm .csv", "ab") do |csv|
        collected_data.each do |row|
          csv << row
        end
      end
    end
  end

  organize AcceptCookies, WorkingProcess
end


class GermanScrapper

end

# Run program
MlScraper.new.scrape
