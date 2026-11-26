require "minitest/autorun"
require "domstride"

class BundleCacheTest < Minitest::Test
  def html(source, initial: "0")
    %(<html><body><output id="count">#{initial}</output><script data-domstride-cache="bundle">#{source}</script></body></html>)
  end

  def test_source_cache_preserves_parser_semantics_and_dynamic_html
    script = 'document.querySelector("#count").textContent += ":" + document.currentScript.dataset.domstrideCache;'
    Domstride::Session.open(bundle_cache: "source", profile: true) do |page|
      page.mount_html(html(script))
      assert_equal "0:bundle", page.text("#count")
      page.mount_html(html(script, initial: "1"))
      assert_equal "1:bundle", page.text("#count")
      assert_equal 1, page.profile[:bundle_hits]
      assert_equal 1, page.profile[:bundle_misses]
      page.mount_html(html('document.querySelector("#count").textContent = "changed";'))
      assert_equal "changed", page.text("#count")
      assert_equal 2, page.profile[:bundle_misses]
      page.mount_html(html(script))
      assert_equal "0:bundle", page.text("#count")
      assert_equal 3, page.profile[:bundle_misses]
    end
  end

  def test_cache_reduces_protocol_bytes
    script = '/*' + ("a" * 20_000) + '*/ document.querySelector("#count").textContent = "1";'
    Domstride::Session.open(bundle_cache: "source", profile: true) do |page|
      page.mount_html(html(script))
      first_bytes = page.profile[:bytes_sent]
      page.reset_profile!
      page.mount_html(html(script))
      assert_equal "1", page.text("#count")
      assert_operator page.profile[:bytes_sent], :<, first_bytes / 10
      assert_equal 1, page.profile[:bundle_hits]
    end
  end

  def test_unmarked_inline_scripts_still_execute
    Domstride::Session.open(bundle_cache: "source", profile: true) do |page|
      page.mount_html('<p id="count">0</p><script>document.querySelector("#count").textContent = "2";</script>')
      assert_equal "2", page.text("#count")
      assert_equal 0, page.profile[:bundle_hits]
      assert_equal 0, page.profile[:bundle_misses]
    end
  end

  def test_compiled_script_runs_in_fresh_document_context
    skip "Compiled cache is jsdom-only" if ENV["DOMSTRIDE_ENGINE"] == "happy-dom"
    script = 'window.__domstrideMountCount = (window.__domstrideMountCount || 0) + 1; document.querySelector("#count").textContent = String(window.__domstrideMountCount);'
    Domstride::Session.open(bundle_cache: "compiled", profile: true) do |page|
      2.times do
        page.mount_html(html(script))
        assert_equal "1", page.text("#count")
      end
      assert_equal 1, page.profile[:bundle_hits]
      assert_equal 1, page.profile[:bundle_misses]
    end
  end

  def test_failed_bundle_mount_does_not_poison_next_mount
    Domstride::Session.open(bundle_cache: "source", profile: true) do |page|
      script = 'document.querySelector("#count").textContent = "1";'
      page.mount_html(html(script))
      assert_raises(Domstride::JavaScriptError) { page.mount_html(html('throw new Error("bundle error")')) }
      page.mount_html(html(script))
      assert_equal "1", page.text("#count")
    end
  end
end
