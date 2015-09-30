require 'data_formatting'

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
