class UnknownDataError < StandardError
end

class UnknownRaceError < UnknownDataError
  def self.validate!(race)
    return if KNOWN_RACES.include? race
    raise UnknownRaceError, "#{race.inspect} is not in #{KNOWN_RACES.inspect}"
  end
end

KNOWN_RACES = [:asian, :black, :pacific_islander, :hispanic, :native_american, :two_or_more, :white].freeze

module DataFormatting
  def percentageable?(maybe_a_number)
    maybe_a_number.to_f.to_s == maybe_a_number
  end

  def percentage(n)
    (n.to_f * 1000).to_i / 1000.0
  end
end
