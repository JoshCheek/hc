require 'csv'

class UnknownDataError < StandardError
end

class ParseCsv
  attr_accessor :data_dir

  def initialize(data_dir)
    self.data_dir = data_dir
  end

  def parse
    @repo_data ||= Hash.new.tap do |repo_data|
      parse_pupil_enrollments            repo_data
      parse_graduation_rates             repo_data
      parse_testing_proficiency_by_grade repo_data
      parse_testing_proficiency_by_race  repo_data
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

  def parse_testing_proficiency_by_grade(repo_data)
    [ '3rd grade students scoring proficient or above on the CSAP_TCAP.csv',
      '8th grade students scoring proficient or above on the CSAP_TCAP.csv',
    ].each do |filename|
      csv_data_from(filename)
        .group_by { |e| e[:location] }
        .each { |district_name, rows|
          formatted_rows = rows.map { |row|
            { subject:     row.fetch(:score).downcase.to_sym,
              grade:       filename.to_i,
              year:        row.fetch(:timeframe).to_i,
              proficiency: row.fetch(:data).to_f.round(3),
            }
          }
          testing = district_for(repo_data, district_name).fetch :testing
          testing.fetch(:by_subject_year_and_grade).concat(formatted_rows)
        }
    end
  end

  def parse_testing_proficiency_by_race(repo_data)
    [ ['Average proficiency on the CSAP_TCAP by race_ethnicity_ Math.csv',    :math],
      ['Average proficiency on the CSAP_TCAP by race_ethnicity_ Reading.csv', :reading],
      ['Average proficiency on the CSAP_TCAP by race_ethnicity_ Writing.csv', :writing],
    ].each do |filename, subject|
      csv_data_from(filename)
        .group_by { |e| e[:location] }
        .each { |district_name, rows|
          formatted_rows = rows.map { |row|
            race = row.fetch(:race_ethnicity).downcase.gsub(/\W/, "_").gsub("hawaiian_", "").to_sym
            { subject:     subject,
              year:        row.fetch(:timeframe).to_i,
              race:        race,
              proficiency: row.fetch(:data).to_f.round(3),
            }
          }
          testing = district_for(repo_data, district_name).fetch :testing
          testing.fetch(:by_subject_year_and_race).concat(formatted_rows)
        }
    end
  end

  def district_for(repo_data, district_name)
    repo_data[district_name] ||= {
      name:       district_name,
      testing:    {
        by_subject_year_and_grade: [],
        by_subject_year_and_race:  [],
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

  def proficient_by_grade(grade)
    validate! grade: grade
    @data.fetch(:by_subject_year_and_grade)
         .select { |datum| datum[:grade] == grade }
         .group_by { |datum| datum[:year] }
         .map { |year, data|
           proficiencies = data.map { |datum| [datum.fetch(:subject), datum.fetch(:proficiency)] }.to_h
           [year, proficiencies]
         }.to_h
  end

  def proficient_for_subject_by_grade_in_year(subject, grade, year)
    records = @data.fetch(:by_subject_year_and_grade)
    validate! grade: grade, subject: subject, year: year, records: records
    records.find { |record| subject == record[:subject] && grade == record[:grade] && year == record[:year] }
           .fetch(:proficiency)
  end

  def proficient_for_subject_by_race_in_year(subject, race, year)
    records = @data.fetch(:by_subject_year_and_race)
    validate! subject: subject, race: race, year: year, records: records
    records.find { |record| subject == record[:subject] && race == record[:race] && year == record[:year] }
           .fetch(:proficiency)
  end


  def proficient_for_subject_in_year(subject, year)
    records = @data.fetch(:by_subject_year_and_race)
    validate! subject: subject, year: year, records: records
    records.find { |record| subject == record[:subject] && :all_students == record[:race] && year == record[:year] }
           .fetch(:proficiency)
  end

  def proficient_by_race_or_ethnicity(race)
    validate! race: race
    result = @data
      .fetch(:by_subject_year_and_race)
      .select   { |r| r.fetch(:race) == race }
      .group_by { |r| r.fetch :year }
      .map { |year, record|
        proficiencies = record.map { |datum| [datum.fetch(:subject), datum.fetch(:proficiency)] }.to_h
        [year, proficiencies]
      }.to_h
    result
  end

  def validate!(validations)
    records = validations.delete :records
    validations.each do |type, value|
      domain = case type
      when :grade   then [3, 8]
      when :race    then [:asian, :black, :pacific_islander, :hispanic, :native_american, :two_or_more, :white]
      when :subject then [:math, :reading, :writing]
      when :year    then records.map { |record| record.fetch(:year) }.uniq.sort
      else raise "WAT: #{type.inspect}"
      end
      domain.include?(value) ||
        raise(UnknownDataError, "#{value.inspect} is not in the accepted domain: #{domain.inspect}")
    end
  end
end
