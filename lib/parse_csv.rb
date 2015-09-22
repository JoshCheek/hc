require 'csv'
require 'data_formatting'

class ParseCsv
  include DataFormatting

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
      parse_economic_reduced_lunch_by_year     repo_data
      parse_median_household_income            repo_data
      parse_school_aged_children_in_poverty    repo_data
      parse_title_1_students                   repo_data
    end
  end

  def parse_median_household_income(repo_data)
    csv_data_from('Median household income.csv')
      .group_by { |e| e.fetch :location }
      .each { |district_name, rows|
        district_for(repo_data, district_name)[:economic_profile][:median_household_income] =
          rows.map { |row| [row.fetch(:timeframe).split("-").map(&:to_i), row.fetch(:data).to_i] }.to_h
      }
  end

  def parse_school_aged_children_in_poverty(repo_data)
    csv_data_from('School-aged children in poverty.csv')
      .group_by { |e| e.fetch :location }
      .each { |district_name, rows|
        district_for(repo_data, district_name)[:economic_profile][:school_aged_children_in_poverty_by_year] =
          rows.select { |row| row.fetch(:dataformat) == 'Percent' }
              .map { |row| [row.fetch(:timeframe).to_i, percentage(row.fetch :data)] }
              .to_h
      }
  end

  def parse_title_1_students(repo_data)
    csv_data_from('Title I students.csv')
      .group_by { |e| e.fetch :location }
      .each { |district_name, rows|
        district_for(repo_data, district_name)[:economic_profile][:title_1_students_by_year] =
          rows.map { |row| [row.fetch(:timeframe).to_i, percentage(row.fetch :data)] }.to_h
      }
  end

  def parse_economic_reduced_lunch_by_year(repo_data)
    csv_data_from('Students qualifying for free or reduced price lunch.csv')
      .group_by { |e| e.fetch :location }
      .each { |district_name, rows|
        district_for(repo_data, district_name)[:economic_profile][:free_or_reduced_lunch_by_year] =
          rows.select { |row| row.fetch(:dataformat) == 'Percent' }
              .map    { |row| [row.fetch(:timeframe).to_i, percentage(row.fetch :data)] }
              .to_h
      }
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
            next unless percentageable? row.fetch(:data)
            { subject:     row.fetch(:score).downcase.to_sym,
              grade:       filename.to_i,
              year:        row.fetch(:timeframe).to_i,
              proficiency: percentage(row.fetch :data),
            }
          }
          testing = district_for(repo_data, district_name).fetch :testing
          testing.fetch(:by_subject_year_and_grade).concat(formatted_rows.compact)
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
    district_name = district_name.upcase
    repo_data[district_name] ||= {
      name:       district_name,
      testing:    {
        by_subject_year_and_grade: [],
        by_subject_year_and_race:  [],
      },
      enrollment: {
        dropout_rates: [],
      },
      economic_profile: {
      },
    }
  end

  def csv_data_from(filename)
    filename = File.join data_dir, filename
    CSV.read(filename, headers: true, header_converters: :symbol).map(&:to_h)
  end
end

