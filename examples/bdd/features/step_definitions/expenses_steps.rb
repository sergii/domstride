Given("I open the expense application") { open_expense_application }
When("I add an amount using Stimulus") { add_amount }
When("I sign in") { sign_in }
When("I enter an expense {string} with amount {string}") { |description, amount| enter_expense(description, amount) }
Then("the identity is {string}") { |text| check_output("identity", text) }
Then("the total is {string}") { |text| check_output("total", text) }
Then("the result is {string}") { |text| check_output("result", text) }
Then("the expense {string} with amount {string} is persisted") { |description, amount| check_persisted(description, amount) }
