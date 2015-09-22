class EconomicProfile
  attr_accessor :title_1_students_by_year, :free_or_reduced_lunch_by_year, :school_aged_children_in_poverty_by_year

  def initialize(data)
    @title_1_students_by_year                = data.fetch :title_1_students_by_year
    @free_or_reduced_lunch_by_year           = data.fetch :free_or_reduced_lunch_by_year
    @school_aged_children_in_poverty_by_year = data.fetch :school_aged_children_in_poverty_by_year, {}
  end

  def free_or_reduced_lunch_in_year(year)
    free_or_reduced_lunch_by_year[year]
  end

  def school_aged_children_in_poverty_in_year(year)
    school_aged_children_in_poverty_by_year[year]
  end

  def title_1_students_in_year(year)
    title_1_students_by_year[year]
  end
end
