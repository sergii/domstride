require "minitest/autorun"
require_relative "scenario"

class RailsReferenceTest < Minitest::Test
  def test_full_interaction
    Domstride::Session.open(app: Rails.application) do |page|
      assert ExpenseScenario.run(page)
    end
  end

  def test_remount
    Domstride::Session.open(app: Rails.application) do |page|
      2.times { assert ExpenseScenario.run(page) }
    end
  end
end
