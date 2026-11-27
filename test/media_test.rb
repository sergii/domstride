require "minitest/autorun"
require "domstride"

class MediaTest < Minitest::Test
  def test_static_media_queries_before_scripts
    skip "Static media profile requires Node/jsdom" if ENV["DOMSTRIDE_RUNTIME"] == "bun" || ENV["DOMSTRIDE_ENGINE"] == "happy-dom"
    Domstride::Session.open(media_profile: "static-desktop") do |page|
      page.mount_html(<<~HTML)
        <p id="result"></p><script>
          const mq = matchMedia("(min-width: 640px)");
          const listener = () => {};
          mq.addEventListener("change", listener);
          mq.removeEventListener("change", listener);
          mq.addListener(listener);
          mq.removeListener(listener);
          document.getElementById("result").textContent = [
            mq.matches,
            matchMedia("(max-width: 639px)").matches,
            matchMedia("(prefers-reduced-motion: reduce)").matches,
            matchMedia("(prefers-color-scheme: dark)").matches
          ].join(",");
        </script>
      HTML
      assert_equal "true,false,true,false", page.text("#result")
      assert_equal "(height: 1000px)", page.evaluate_script('matchMedia("(height: 1000px)").media')
      assert_equal true, page.evaluate_script('matchMedia("(height: 1000px)").matches')
      assert_match(/UNSUPPORTED_MEDIA_QUERY/, assert_raises(Domstride::JavaScriptError) {
        page.evaluate_script('matchMedia("(unknown-feature: foo)").matches')
      }.message)
    end
  end

  def test_invalid_profile
    assert_raises(ArgumentError) { Domstride::Session.new(media_profile: "invalid") }
  end
end
