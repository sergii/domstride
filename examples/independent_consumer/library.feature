@feature:LIB-001
Feature: Borrow a library book
  Overview:
  A reader can borrow an available book.
  Business value:
  Keep the catalog availability accurate.

  @scenario:LIB-001-01 @replay
  Scenario: Borrow an available book
    Given an available book
    When I borrow the book
    Then the book is marked as borrowed
