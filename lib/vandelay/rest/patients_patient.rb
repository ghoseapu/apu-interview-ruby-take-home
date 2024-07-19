require 'vandelay/services/patients'
require 'vandelay/services/patient_records'

module Vandelay
  module REST
    module PatientsPatient
      def self.registered(app)
        # endpoint that retrieves a single patient from the db
        app.get '/patients/:id' do
          patient_id = params[:id]
          begin
            patient = Vandelay::Services::Patients.new.retrieve_one(patient_id)
            if patient
              status 200
              patient.to_json
            else
              status 404
              { error: "There is no patient found with id #{patient_id}" }.to_json
            end
          rescue StandardError => e
            status 500
            { error: 'Internal server error', message: e.message }.to_json
          end
        end

        # endpoint that retrieves a single patient record from external
        app.get '/patients/:patient_id/record' do
          patient_id = params[:patient_id]
          begin
            patient = Vandelay::Services::PatientRecords.new.retrieve_record_for_patient(patient_id)
            if patient
              status 200
              patient.to_json
            else
              status 404
              { error: "There is no patient found with id #{patient_id}" }.to_json
            end
          rescue StandardError => e
            status 500
            { error: 'Internal server error', message: e.message }.to_json
          end
        end
      end
    end
  end
end
