require 'parse_csv'
require 'district'
require 'json'
require 'rest-client'
require 'pry'

class ParseJson

  attr_reader :data

  def initialize(data)
    @data = data
  end

  def values_to_sym(hashes, key)
    hashes.each do |hash|
      hash[key] = hash[key].to_sym
    end
  end

  def parse
    @data = JSON.parse(@data, :symbolize_names=>true)
    @data = data.map do |district_name, data|
      testing = data.delete :statewide_testing
      data[:testing] = testing
      values_to_sym testing[:by_subject_year_and_grade], :subject
      values_to_sym testing[:by_subject_year_and_race],  :subject
      values_to_sym testing[:by_subject_year_and_race],  :race

      economic_profile = data[:economic_profile]
      enrollment       = data[:enrollment]

      keys_to_int economic_profile, :title_1_students_by_year
      keys_to_int economic_profile, :free_or_reduced_lunch_by_year
      keys_to_int economic_profile, :school_aged_children_in_poverty_by_year

      keys_to_int enrollment,       :remediation_by_year
      keys_to_int enrollment,       :participation_by_year
      keys_to_int enrollment,       :graduation_rate_by_year
      keys_to_int enrollment,       :special_education_by_year
      keys_to_int enrollment,       :online_participation_by_year
      keys_to_int enrollment,       :kindergarten_participation_by_year

      values_to_sym enrollment[:dropout_rates], :category
      values_to_sym enrollment[:participation_by_race_and_year], :race

      [district_name.to_s, data]
    end.to_h

    @data
  end

  def keys_to_int(hash, key)
    hash[key] = hash[key].map { |key, value| [key.to_s.to_i, value] }.to_h
  end
end


class DistrictRepository
  def self.from_csv(data_dir)
    new ParseCsv.new(data_dir).parse
  end

  def self.from_api(url)
    data = RestClient.get url
    new ParseJson.new(data).parse
  end

  attr_reader :districts_by_name

  def initialize(data)
    @districts_by_name = data.map { |name, district_data| [name.downcase, District.new(name, district_data)] }.to_h
  end

  def find_by_name(name)
    districts_by_name[name.downcase]
  end

  def find_all_matching(fragment)
    fragment = fragment.downcase
    districts_by_name.select { |name, district| name.include? fragment }.map(&:last)
  end

  def districts
    districts_by_name.values
  end
end
