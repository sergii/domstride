require "minitest/autorun"
require "domstride/capybara"

class JavaScriptApiTest < Minitest::Test
  def test_native_execution_and_json_results
    Domstride::Session.open do |page|
      page.mount_html('<p id="result">Initial</p>')
      page.execute_script('document.querySelector("#result").textContent = arguments[0]', "Updated")
      assert_equal "Updated", page.text("#result")
      assert_equal({"text" => "Updated", "values" => [1, true, nil]}, page.evaluate_script('({text: document.querySelector("#result").textContent, values: arguments[0]})', [1, true, nil]))
      assert_raises(Domstride::JavaScriptError) { page.execute_script('throw new Error("script failure")') }
      assert_raises(Domstride::Error) { page.evaluate_script('document.body') }
      assert_raises(Domstride::Error) { page.evaluate_script('Promise.resolve(1)') }
    end
  end

  def test_capybara_element_arguments
    app = ->(_) { [200, {"content-type" => "text/html"}, ['<input id="field"><p id="result">Initial</p>']] }
    page = Capybara::Session.new(:domstride, app)
    begin
      page.visit("/")
      field = page.find(:css, "#field")
      page.execute_script("arguments[0].value = arguments[1]", field, "Lunch")
      assert_equal "Lunch", field.value
      assert_equal "field", page.evaluate_script("arguments[0].id", field)
      assert_raises(Capybara::NotSupportedByDriverError) { page.evaluate_script("document.body") }
      raw = field.base
      page.reset!
      page.visit("/")
      assert_raises(Domstride::CapybaraAdapter::StaleElement) { page.driver.execute_script("arguments[0].value = 'stale'", raw) }
    ensure
      page.driver.quit
    end
  end
end
