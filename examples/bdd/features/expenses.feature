@domstride
Feature: Expenses in a Rails application
  Scenario: Create an expense using real Turbo and Stimulus
    Given I open the expense application
    Then the identity is "Anonymous"
    When I add an amount using Stimulus
    Then the total is "25"
    When I sign in
    Then the identity is "Signed in"
    When I enter an expense "Lunch" with amount "0"
    Then the result is "Invalid expense"
    When I enter an expense "Lunch" with amount "25"
    Then the result is "Saved"
    And the expense "Lunch" with amount "25" is persisted

  Scenario: Start with an isolated session
    Given I open the expense application
    Then the identity is "Anonymous"
    And the total is "0"
