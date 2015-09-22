require 'parse_csv'
require 'district'

class DistrictRepository
  def self.from_csv(data_dir)
    new ParseCsv.new(data_dir).parse
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
