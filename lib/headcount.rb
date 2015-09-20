require 'csv'

class UnknownDataError < StandardError
end

class UnknownRaceError < UnknownDataError
  def self.validate!(race)
    return if KNOWN_RACES.include? race
    raise UnknownRaceError, "#{race.inspect} is not in #{KNOWN_RACES.inspect}"
  end
end

KNOWN_RACES = [:asian, :black, :pacific_islander, :hispanic, :native_american, :two_or_more, :white].freeze

class ParseCsv
  attr_accessor :data_dir

  def initialize(data_dir)
    self.data_dir = data_dir
  end

  def parse
    @repo_data ||= Hash.new.tap do |repo_data|
      parse_pupil_enrollments                  repo_data
      parse_online_enrollments                 repo_data
      parse_graduation_rates                   repo_data
      parse_testing_proficiency_by_grade       repo_data
      parse_testing_proficiency_by_race        repo_data
      parse_dropout_rates                      repo_data
      parse_kindergarten_participation_by_year repo_data
      parse_pupil_enrollment_by_race           repo_data
      parse_special_education_by_year          repo_data
      parse_remediation_by_year                repo_data
    end
  end

  def parse_remediation_by_year(repo_data)
    csv_data_from('Remediation in higher education.csv')
      .group_by { |e| e.fetch :location }
      .each { |district_name, rows|
        district_for(repo_data, district_name)[:enrollment][:remediation_by_year] =
          rows.map { |row| [row.fetch(:timeframe).to_i, percentage(row.fetch :data)] }
              .to_h
      }
  end

  def parse_special_education_by_year(repo_data)
    csv_data_from('Special education.csv')
      .group_by { |e| e.fetch :location }
      .each { |district_name, rows|
        district_for(repo_data, district_name)[:enrollment][:special_education_by_year] =
          rows.map { |row| [row.fetch(:timeframe).to_i, percentage(row.fetch :data)] }.to_h
      }
  end

  def parse_online_enrollments(repo_data)
    csv_data_from('Online pupil enrollment.csv')
      .group_by { |e| e.fetch :location }
      .each { |district_name, rows|
        district_for(repo_data, district_name)[:enrollment][:online_participation_by_year] =
          rows.map { |row| [row.fetch(:timeframe).to_i, row.fetch(:data).to_i] }.to_h
      }
  end

  def parse_kindergarten_participation_by_year(repo_data)
    csv_data_from('Kindergartners in full-day program.csv')
      .group_by { |e| e.fetch :location }
      .each { |district_name, rows|
        district_for(repo_data, district_name)[:enrollment][:kindergarten_participation_by_year] =
          rows.map { |row| [row.fetch(:timeframe).to_i, percentage(row.fetch :data)] }.to_h
      }
  end

  def parse_pupil_enrollments(repo_data)
    csv_data_from("Pupil enrollment.csv")
      .group_by { |e| e.fetch :location }
      .each { |district_name, rows|
        enrollment = district_for(repo_data, district_name)[:enrollment]
        enrollment[:participation_by_year] = rows.map { |row| [row[:timeframe].to_i, row[:data].to_i] }.to_h
      }
  end

  def parse_pupil_enrollment_by_race(repo_data)
    csv_data_from("Pupil enrollment by race_ethnicity.csv")
      .group_by { |e| e.fetch :location }
      .each { |district_name, rows|
        district_for(repo_data, district_name)[:enrollment][:participation_by_race_and_year] =
          rows.select { |row| row.fetch(:dataformat) == "Percent" && row.fetch(:race) != "Total" }
              .map { |row| {race: category(row.fetch :race), year: row.fetch(:timeframe).to_i, rate: percentage(row.fetch :data)} }
      }
  end

  def parse_graduation_rates(repo_data)
    csv_data_from('High school graduation rates.csv')
      .group_by { |e| e[:location] }
      .each { |district_name, rows|
        district_for(repo_data, district_name)[:enrollment][:graduation_rate_by_year] =
          rows.map { |row| [row[:timeframe].to_i, percentage(row[:data])] }.to_h
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
              proficiency: percentage(row.fetch :data),
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
            { subject:     subject,
              year:        row.fetch(:timeframe).to_i,
              race:        category(row.fetch :race_ethnicity),
              proficiency: percentage(row.fetch :data),
            }
          }
          testing = district_for(repo_data, district_name).fetch :testing
          testing.fetch(:by_subject_year_and_race).concat(formatted_rows)
        }
    end
  end

  def category(human_name)
    case human_name.downcase
    when /pacific.*island/ then :pacific_islander
    when /hispanic/        then :hispanic
    when /american/        then :native_american
    when /asian/           then :asian
    when /black/           then :black
    when /female/          then :female
    when /male/            then :male
    when /all/             then :all
    when /two/             then :two_or_more
    when /white/           then :white
    else raise "WHAT IS THIS?! #{human_name.inspect}"
    end
  end

  def parse_dropout_rates(repo_data)
    csv_data_from("Dropout rates by race and ethnicity.csv")
      .group_by { |e| e.fetch :location }
      .each { |district_name, rows|
        formatted_rows = rows.map { |row|
          # {:location=>"Colorado", :category=>"Female Students", :timeframe=>"2011", :dataformat=>"Percent", :data=>"0.028"},
          { year:     row.fetch(:timeframe).to_i,
            rate:     percentage(row.fetch :data),
            category: category(row.fetch :category),
          }
        }
        enrollment = district_for(repo_data, district_name).fetch :enrollment
        enrollment[:dropout_rates] += formatted_rows
      }
  end

  def district_for(repo_data, district_name)
    repo_data[district_name] ||= {
      name:       district_name,
      testing:    {
        by_subject_year_and_grade: [],
        by_subject_year_and_race:  [],
      },
      enrollment: {
        dropout_rates: [],
      },
    }
  end

  def csv_data_from(filename)
    filename = File.join data_dir, filename
    CSV.read(filename, headers: true, header_converters: :symbol).map(&:to_h)
  end

  def percentage(n)
    (n.to_f * 1000).to_i / 1000.0
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
  attr_accessor :graduation_rate_by_year, :kindergarten_participation_by_year, :online_participation_by_year, :participation_by_year, :participation_by_race_and_year, :special_education_by_year, :remediation_by_year

  def initialize(data)
    @dropout_rates                      = data.fetch :dropout_rates
    @graduation_rate_by_year            = data.fetch :graduation_rate_by_year
    @kindergarten_participation_by_year = data.fetch :kindergarten_participation_by_year
    @participation_by_year              = data.fetch :participation_by_year
    @online_participation_by_year       = data.fetch :online_participation_by_year
    @participation_by_race_and_year     = data.fetch :participation_by_race_and_year
    @special_education_by_year          = data.fetch :special_education_by_year
    @remediation_by_year                = data.fetch :remediation_by_year
  end

  def remediation_in_year(year)
    remediation_by_year[year]
  end

  def special_education_in_year(year)
    special_education_by_year[year]
  end

  def participation_by_race_or_ethnicity(race)
    UnknownRaceError.validate! race
    participation_by_race_and_year.select { |row| row.fetch(:race) == race }.map { |row| [row.fetch(:year), row.fetch(:rate)] }.to_h
  end

  def participation_by_race_or_ethnicity_in_year(year)
    results = participation_by_race_and_year.select { |row| row.fetch(:year) == year }.map { |row| [row.fetch(:race), row.fetch(:rate)] }.to_h
    return nil if results.empty?
    results
  end

  def participation_in_year(year)
    participation_by_year[year]
  end

  def online_participation_in_year(year)
    online_participation_by_year[year]
  end

  def kindergarten_participation_in_year(year)
    kindergarten_participation_by_year[year]
  end

  def graduation_rate_in_year(year)
    graduation_rate_by_year[year]
  end

  def participation_in_year(year)
    participation_by_year[year]
  end

  def dropout_rate_in_year(year)
    rate = dropout_rate_by(year: year, category: :all).first
    rate && rate.fetch(:rate)
  end

  def dropout_rate_for_race_or_ethnicity(race)
    UnknownRaceError.validate!(race)
    rates = dropout_rate_by(category: race).map { |rate| [rate.fetch(:year), rate.fetch(:rate)] }.to_h
    rates
  end

  def dropout_rate_for_race_or_ethnicity_in_year(race, year)
    UnknownRaceError.validate!(race)
    rate = dropout_rate_by(category: race, year: year).first
    rate && rate.fetch(:rate)
  end

  def dropout_rate_by_gender_in_year(year)
    rates = @dropout_rates.select { |rate| [:male, :female].include?(rate.fetch :category) && year == rate.fetch(:year) }
                          .map { |rate| [rate.fetch(:category), rate.fetch(:rate)] }
                          .to_h
    return nil if rates.empty?
    rates
  end

  def dropout_rate_by_race_in_year(year)
    rates = dropout_rate_by(year: year, category: KNOWN_RACES)
              .map { |rate| [rate.fetch(:category), rate.fetch(:rate)] }
              .to_h
    return nil if rates.empty?
    rates
  end

  private

  def dropout_rate_by(attributes)
    rates = @dropout_rates

    if attributes.key? :category
      categories = Array attributes.fetch :category
      rates      = rates.select { |rate| categories.include? rate.fetch :category }
    end

    if attributes.key? :year
      year  = attributes.fetch :year
      rates = rates.select { |rate| year == rate.fetch(:year) }
    end

    rates
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
    records.find { |record| subject == record[:subject] && :all == record[:race] && year == record[:year] }
           .fetch(:proficiency)
  end

  def proficient_by_race_or_ethnicity(race)
    validate! race: race
    @data
      .fetch(:by_subject_year_and_race)
      .select   { |r| r.fetch(:race) == race }
      .group_by { |r| r.fetch :year }
      .map { |year, record|
        proficiencies = record.map { |datum| [datum.fetch(:subject), datum.fetch(:proficiency)] }.to_h
        [year, proficiencies]
      }.to_h
  end

  def validate!(validations)
    records = validations.delete :records
    validations.each do |type, value|
      domain = case type
      when :grade   then [3, 8]
      when :race    then KNOWN_RACES
      when :subject then [:math, :reading, :writing]
      when :year    then records.map { |record| record.fetch(:year) }.uniq.sort
      else raise "WAT: #{type.inspect}"
      end
      domain.include?(value) ||
        raise(UnknownDataError, "#{value.inspect} is not in the accepted domain: #{domain.inspect}")
    end
  end
end
