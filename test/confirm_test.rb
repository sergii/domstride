require "minitest/autorun"
require "domstride/capybara"

class ConfirmTest < Minitest::Test
  def setup
    app = ->(_) { [200, {"content-type" => "text/html"}, [<<~HTML]] }
      <button id="confirm" onclick="document.querySelector('#result').textContent = confirm('Delete this listing?') ? 'deleted' : 'kept'">Delete</button>
      <button id="async" onclick="setTimeout(() => { document.querySelector('#result').textContent = confirm('Delayed?') ? 'yes' : 'no' }, 20)">Delayed</button>
      <p id="result">initial</p>
    HTML
    @page = Capybara::Session.new(:domstride, app)
    @page.visit("/")
  end

  def teardown
    @page.driver.quit
  end

  def test_accept_and_dismiss_return_dialog_text_and_control_the_branch
    assert_equal "Delete this listing?", @page.accept_confirm("Delete") { @page.find(:css, "#confirm").click }
    assert @page.has_css?("#result", text: "deleted")
    assert_equal "Delete this listing?", @page.dismiss_confirm { @page.find(:css, "#confirm").click }
    assert @page.has_css?("#result", text: "kept")
  end

  def test_mismatched_confirmation_does_not_accept
    assert_raises(Capybara::ModalNotFound) do
      @page.accept_confirm("Wrong text") { @page.find(:css, "#confirm").click }
    end
    assert @page.has_css?("#result", text: "kept")
    assert_equal "Delete this listing?", @page.accept_confirm { @page.find(:css, "#confirm").click }
  end

  def test_wait_for_delayed_confirmation
    assert_equal "Delayed?", @page.accept_confirm(wait: 1) { @page.find(:css, "#async").click }
    assert @page.has_css?("#result", text: "yes")
  end

  def test_missing_and_unexpected_dialogs_fail
    assert_raises(Capybara::ModalNotFound) { @page.accept_confirm(wait: 0.05) {} }
    assert_raises(Domstride::JavaScriptError) { @page.find(:css, "#confirm").click }
    assert @page.has_css?("#result", text: "kept")
  end

  def test_block_failure_clears_scope
    assert_raises(RuntimeError) { @page.accept_confirm { raise "test block failure" } }
    assert_equal "Delete this listing?", @page.accept_confirm { @page.find(:css, "#confirm").click }
  end
end
