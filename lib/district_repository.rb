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

  def parse
    @data = JSON.parse(@data, :symbolize_names=>true)
    @data = data.map do |district_name, data|
      [district_name.to_s, data]
    end.to_h

    data.each do |district_name, data|
      data[:testing] = data.delete :statewide_testing
    end
    @data
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
