require 'data_formatting'
require 'data_formatting'

class HeadcountAnalyst
  include DataFormatting

  attr_accessor :repository

  def initialize(repository)
    self.repository = repository
  end

  def top_statewide_testing_year_over_year_growth_in_3rd_grade(subject)
    district = repository
                 .districts
                 .select { |district| district.statewide_testing.average_growth(3, subject) }
                 .max_by { |district| district.statewide_testing.average_growth(3, subject) }
    [district.name, percentage(district.statewide_testing.average_growth(3, subject))]
  end
end
