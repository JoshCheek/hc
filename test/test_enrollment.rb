
class TestEnrollments < Minitest::Test
  def test_it_tells_you_how_many_people_were_enrolled_by_year_which_comes_from_pupil_data
    enrollment = Enrollment.new(pupil: {2009 => 10, 2010 => 100})
    assert_equal 10,  enrollment.in_year(2009)
    assert_equal 100, enrollment.in_year(2010)
  end
end
