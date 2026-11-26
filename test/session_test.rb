require "minitest/autorun"
require "domstride"

class SessionTest < Minitest::Test
  HTML = File.read(File.expand_path("../examples/counter.html", __dir__))

  def test_real_javascript_click
    Domstride::Session.open do |page|
      page.mount_html(HTML)
      2.times { page.click("#increment") }
      assert_equal "2", page.text("#count")
      assert page.assert_text("#count", "2")
    end
  end

  def test_remount_isolates_document
    Domstride::Session.open do |page|
      page.mount_html(HTML)
      page.click("#increment")
      page.mount_html(HTML)
      assert_equal "0", page.text("#count")
      assert_equal 1, page.count("button")
    end
  end

  def test_missing_element_and_failed_assertion
    Domstride::Session.open do |page|
      page.mount_html(HTML)
      assert_raises(Domstride::Error) { page.click("#missing") }
      assert_raises(Domstride::Error) { page.assert_text("#count", "99") }
      assert_equal "0", page.text("#count")
    end
  end
end
