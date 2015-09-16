require 'csv'

class ParseCsv
  attr_accessor :data_dir

  def initialize(data_dir)
    self.data_dir = data_dir
  end

  def parse
    @repo_data ||= Hash.new.tap do |repo_data|
      parse_pupil_enrollments repo_data
      parse_graduation_rates  repo_data
    end
  end

  def parse_pupil_enrollments(repo_data)
    csv_data_from("Pupil enrollment.csv")
      .group_by { |e| e[:location] }
      .each { |district_name, rows|
        district_for(repo_data, district_name)[:enrollment][:pupil] =
          rows.map { |row| [row[:timeframe].to_i, row[:data].to_i] }.to_h
      }
  end

  def parse_graduation_rates(repo_data)
    csv_data_from('High school graduation rates.csv')
      .group_by { |e| e[:location] }
      .each { |district_name, rows|
        district_for(repo_data, district_name)[:enrollment][:graduation_rate][:for_high_school_in_year] =
          rows.map { |row| [row[:timeframe].to_i, row[:data].to_f] }.to_h
      }
  end

  def district_for(repo_data, district_name)
    repo_data[district_name] ||= {
      enrollment: {
        graduation_rate: {}
      }
    }
  end

  def csv_data_from(filename)
    filename = File.join data_dir, filename
    CSV.read(filename, headers: true, header_converters: :symbol).map(&:to_h)
  end
end


class DistrictRepository
  def self.from_csv(data_dir)
    new ParseCsv.new(data_dir).parse
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
  attr_reader :graduation_rate

  def initialize(data)
    @graduation_rate = GraduationRate.new data[:graduation_rate]
    @pupil_data      = data[:pupil]
  end

  def in_year(year)
    @pupil_data.fetch year
  end
end

class GraduationRate
  def initialize(data)
    @data = data
  end

  def for_high_school_in_year(year)
    @data.fetch(:for_high_school_in_year).fetch(year)
  end
end
