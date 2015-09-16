require 'csv'
class DistrictRepository
  def self.from_csv(data_dir)
    repo_data   = {}

    # enrollments
    filename    = File.join data_dir, "Pupil enrollment.csv"
    enrollments = CSV.read(filename, headers: true, header_converters: :symbol).map { |row| row.to_h }
    enrollments.group_by { |e| e[:location] }
               .each { |district_name, rows|
                 district_data   = (repo_data[district_name] ||= {})
                 enrollment_data = (district_data[:enrollment] ||= {})
                 enrollment_data[:pupil] = rows.map { |row| [row[:timeframe].to_i, row[:data].to_i] }.to_h
               }

    DistrictRepository.new repo_data
  end

  attr_reader :districts

  def initialize(data)
    @districts = data.map { |name, district_data| [name, District.new(name, district_data)] }.to_h
  end

  def find_by_name(name)
    districts.fetch name
  end
end


class District
  attr_reader :name, :enrollment
  def initialize(name, data)
    @name       = name
    @enrollment = Enrollment.new data[:enrollment]
  end
end

class Enrollment
  def initialize(data)
    @pupil_data = data[:pupil]
  end

  def in_year(year)
    @pupil_data.fetch year
  end
end

