module DataFormatting
  def percentageable?(maybe_a_number)
    maybe_a_number.to_f.to_s == maybe_a_number
  end

  def percentage(n)
    (n.to_f * 1000).to_i / 1000.0
  end
end


