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

  def average_growth(grade, subject)
    min, max = @data.fetch(:by_subject_year_and_grade)
                    .select { |idk| idk.fetch(:grade) == grade && idk.fetch(:subject) == subject }
                    .minmax_by { |idfk| idfk.fetch :year }

    return nil if !min || min == max

    difference      = max.fetch(:proficiency) - min.fetch(:proficiency)
    number_of_years = max.fetch(:year) - min.fetch(:year)
    difference / number_of_years
  end
end
