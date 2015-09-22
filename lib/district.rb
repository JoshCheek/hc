require 'enrollment'
require 'economic_profile'
require 'statewide_testing'

class District
  attr_reader :name, :enrollment, :statewide_testing, :economic_profile

  def initialize(name, data)
    @name              = name.upcase
    @enrollment        = Enrollment.new       data.fetch(:enrollment)
    @statewide_testing = StatewideTesting.new data.fetch(:testing)
    @economic_profile  = EconomicProfile.new  data.fetch(:economic_profile)
  end
end
