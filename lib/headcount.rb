require 'csv'

class ParseCsv
  attr_accessor :data_dir

  def initialize(data_dir)
    self.data_dir = data_dir
  end

  def parse
    @repo_data ||= Hash.new.tap do |repo_data|
      parse_pupil_enrollments   repo_data
      parse_graduation_rates    repo_data
      parse_testing_proficiency repo_data
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

  def parse_testing_proficiency(repo_data)
    [ '3rd grade students scoring proficient or above on the CSAP_TCAP.csv',
      # '4th grade students scoring proficient or advanced on CSAP_TCAP.csv',
      '8th grade students scoring proficient or above on the CSAP_TCAP.csv',
    ].each do |filename|
      csv_data_from(filename)
        .group_by { |e| e[:location] }
        .each { |district_name, rows|
          formatted_rows = rows.map { |row|
            { subject:     row.fetch(:score).downcase.to_sym,
              grade:       filename.to_i,
              year:        row.fetch(:timeframe).to_i,
              proficiency: row.fetch(:data).to_f,
            }
          }
          testing = district_for(repo_data, district_name).fetch :testing
          testing.fetch(:by_subject_grade_and_year).concat(formatted_rows)
        }
    end
  end

  def district_for(repo_data, district_name)
    repo_data[district_name] ||= {
      name:       district_name,
      testing:    {
        by_subject_grade_and_year: []
      },
      enrollment: {
        graduation_rate: {
        }
      },
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
    @districts = data.map { |name, district_data| [name.downcase, District.new(name, district_data)] }.to_h
  end

  def find_by_name(name)
    districts[name.downcase]
  end

  def find_all_matching(fragment)
    fragment = fragment.downcase
    districts.select { |name, district| name.include? fragment }.map(&:last)
  end
end


class District
  attr_reader :name, :enrollment, :statewide_testing

  def initialize(name, data)
    @name              = name.upcase
    @enrollment        = Enrollment.new data.fetch(:enrollment)
    @statewide_testing = StatewideTesting.new data.fetch(:testing)
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

class StatewideTesting
  def initialize(data)
    @data = data
  end

  def proficient_for_subject_by_grade_in_year(subject, grade, year)
    @data.fetch(:by_subject_grade_and_year)
         .find { |data|
            subject == data[:subject] &&
              grade ==   data[:grade] &&
              year  ==   data[:year]
         }.fetch(:proficiency)
  end
end
