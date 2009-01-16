require 'test/unit'

module Test::Unit::Assertions
  def assert_equal_ignoring_whitespace_and_quote_style(expected, actual)
    return true if expected == actual
    e_idx = a_idx = 0
    while e_idx < expected.length || a_idx < actual.length
      if expected[e_idx..e_idx] =~ /\s/
        e_idx += 1
      elsif actual[a_idx..a_idx] =~ /\s/
        a_idx += 1
      elsif expected[e_idx] != actual[a_idx] &&
          !(expected[e_idx..e_idx] =~ /['"]/ && actual[a_idx..a_idx] =~ /['"]/)
        left_range = [0, e_idx - 20].max .. [expected.length, e_idx + 20].min
        right_range = [0, a_idx - 20].max .. [actual.length, a_idx + 20].min
        assert(false, "Divergence at expected character #{e_idx}: Expected ...#{expected[left_range]}..., got ...#{actual[right_range]}..")
      else 
        e_idx += 1
        a_idx += 1
      end
    end
  end
end
