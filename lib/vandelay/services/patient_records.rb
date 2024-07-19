require 'json'
require 'net/http'
require 'uri'
require 'yaml'
require 'vandelay/models/patient'

module Vandelay
  module Services
    class PatientRecords
      def retrieve_record_for_patient(patient)
        patient_data = Vandelay::Models::Patient.with_id(patient)
        if patient_data.nil?
          return { info: "There is no patient found with patient id #{patient}" }
        end
        
        records_vendor = patient_data["records_vendor"]
        vendor_id = patient_data["vendor_id"]

        if records_vendor.nil? || vendor_id.nil?
          return { info: "No records vendor or/and vendor id exist(s) for patient id #{patient}" }
        end

        # Load the configuration file
        config = YAML.load_file('./config.dev.yml')
        # Get page URL
        page_url = config['persistence']['pg_url']
        # Get the API base URLs from the config
        api_base_url = config['integrations']['vendors']["#{records_vendor}"]['api_base_url']
        # Get the auth token endpoint from the config
        auth_token_endpoint = config['integrations']['vendors']["#{records_vendor}"]['auth_token_endpoint']
        # Get the patient records endpoint from the config
        patient_records_endpoint = config['integrations']['vendors']["#{records_vendor}"]['patient_records_endpoint']
        # Fetch data from both APIs
        data = fetch_data(page_url, api_base_url, patient_records_endpoint)
        puts "Data from API #{records_vendor}: #{data}"

        # Determine which JSON file to use based on records_vendor
        json_data = fetch_json_data(records_vendor)
        if json_data.nil?
          return { error: "No records vendor value found in database for patient with id #{patient_data["id"]}" }
        end

        route = fetch_route(records_vendor)
        if route.nil?
          return { error: "Missing route configuration for patient with id #{patient_data["id"]}" }
        end

        # Find patient record in the selected JSON file using vendor_id
        record = find_record_in_json(json_data, vendor_id, records_vendor)

        if record.nil?
          return { error: "Record with vendor_id #{vendor_id} not found in JSON file" }
        end

        # Fetch auth token
        auth_token = fetch_auth_token(json_data, records_vendor, route)
        if auth_token.nil?
          return { error: "Failed to fetch auth token from #{records_vendor} - #{route}" }
        end

        # Prepare headers with Authorization token
        headers = {
          'Authorization' => "Bearer #{auth_token}",
          'Content-Type' => 'application/json',
          'Accept' => 'application/json'
        }

        # Prepare response in the specified format based on records_vendor
        case records_vendor
        when 'one'
          {
            province: record['province'],
            allergies: record['allergies'],
            num_medical_visits: record['recent_medical_visits']
          }
        when 'two'
          {
            province: record['province_code'],
            allergies: record['allergies_list'],
            num_medical_visits: record['medical_visits_recently']
          }
        end
        
      end

      private

      # Helper method to fetch JSON data based on records_vendor
      def fetch_json_data(records_vendor)
        case records_vendor
        when 'one'
          File.read('externals/mock_api_one/db.json')
        when 'two'
          File.read('externals/mock_api_two/db.json')
        else
          nil
        end
      end

      # Helper method to fetch route from routes.json based on records_vendor and endpoint
      def fetch_route(records_vendor)
        routes_file = "externals/mock_api_#{records_vendor}/routes.json"
        
        unless File.exist?(routes_file)
          puts "Error: Routes file not found - #{routes_file}"
          return nil
        end
      
        begin
          routes_data = JSON.parse(File.read(routes_file))
          case records_vendor
          when 'one'
            routes_data["/auth"]
          when 'two'
            routes_data["/auth_tokens"]
          end
        rescue JSON::ParserError => e
          puts "Error parsing JSON from routes file - #{e.message}"
          nil
        end
      end

      # Helper method to fetch auth token based on records_vendor and endpoint
      def fetch_auth_token(json_data, records_vendor, endpoint)
        data = JSON.parse(json_data)
        token_parts = endpoint.split('/')
        token_data = data[token_parts[1]]
        auth_token = token_data.find { |r| r['id'] == token_parts[2] }
        case records_vendor
        when 'one'
          auth = auth_token["token"]
        when 'two'
          auth = auth_token["auth_token"]
        end
      end

      # Define a method to fetch data from an API
      def fetch_data(page_url, api_base_url, endpoint)
        uri = URI.parse("#{page_url}#{api_base_url}#{endpoint}")

        unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
          raise ArgumentError, "Invalid URI: #{uri}"
        end

        response = Net::HTTP.get_response(uri)

        if response.is_a?(Net::HTTPSuccess)
          return response.body
        else
          puts "Failed to fetch data from #{uri}"
          return nil
        end
      rescue URI::InvalidURIError => e
        puts "Invalid URI: #{e.message}"
        return nil
      rescue StandardError => e
        puts "Error fetching data: #{e.message}"
        return nil
      end
      
      # Helper method to find record in JSON data based on vendor_id and records_vendor
      def find_record_in_json(json_data, vendor_id, records_vendor)
        data = JSON.parse(json_data)
        case records_vendor
        when 'one'
          records = data['patients']
        when 'two'
          records = data['records']
        end
        record = records.find { |r| r['id'] == vendor_id }
        record
      end

    end
  end
end