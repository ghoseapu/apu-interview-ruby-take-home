module Vandelay
  module Services
    class PatientRecords
      def retrieve_record_for_patient(patient)
        patient_data = Vandelay::Services::Patients.new.retrieve_one(patient)
        if patient_data.nil?
          data = {"info": "No patient with this ID exists"}
        else
          data = {"info": "There is no vendor found for this patient."}
          if patient_data["records_vendor"] == 'one'
            # Load data from externals/mock_api_one/db.json
            api_one_data = JSON.parse(File.read('./externals/mock_api_one/db.json'))
            # get patient info
            patient_info = api_one_data["patients"]
            # find data for specific vendor id
            patient = patient_info.find { |hash| hash["id"] == patient_data["vendor_id"] }
            data = {
                "patient_id": patient["id"],
                "province": patient["province"],
                "allergies": patient["allergies"],
                "num_medical_visits": patient["recent_medical_visits"]
            }  
          elsif patient_data["records_vendor"] == 'two'
            # Load data from externals/mock_api_two/db.json
            api_two_data = JSON.parse(File.read('./externals/mock_api_two/db.json'))
            # get record info
            record_info = api_two_data["records"]
            # find data for specific vendor id
            record = record_info.find { |hash| hash["id"] == patient_data["vendor_id"] }
            data = {
              "patient_id": record["id"],
              "province": record["province_code"],
              "allergies": record["allergies_list"],
              "num_medical_visits": record["medical_visits_recently"]
            }
          end
        end
        data
      end
    end
  end
end