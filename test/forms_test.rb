require "minitest/autorun"
require "domstride/capybara"
require "tempfile"
require "rack"

class FormsTest < Minitest::Test
  def with_page(html, app: nil)
    page = Capybara::Session.new(:domstride, app || ->(_) { [200, {"content-type" => "text/html"}, [html]] })
    page.visit("/")
    yield page
  ensure
    page&.driver&.quit
  end

  def test_select_and_multiselect_events
    with_page(<<~HTML) do |page|
      <select id="single"><option value="a">A</option><option id="b" value="b">B</option><option id="blocked" disabled>C</option></select>
      <select id="multi" multiple><option id="x" value="x">X</option><option id="y" value="y">Y</option></select>
      <output id="changes"></output>
      <script>document.addEventListener("change", e => document.querySelector("#changes").textContent += e.target.id + ";");</script>
    HTML
      page.find(:css, "#b").select_option
      page.find(:css, "#b").select_option
      assert_equal "b", page.find(:css, "#single").value
      assert_raises(Capybara::NotSupportedByDriverError) { page.find(:css, "#b").unselect_option }
      assert_raises(Domstride::Error) { page.find(:css, "#blocked").select_option }
      page.find(:css, "#x").select_option
      page.find(:css, "#y").select_option
      assert_equal %w[x y], page.find(:css, "#multi").value
      page.find(:css, "#x").unselect_option
      assert_equal ["y"], page.find(:css, "#multi").value
      assert_equal "single;multi;multi;multi;", page.find(:css, "#changes").text
    end
  end

  def test_keyboard_editing_and_cancelled_event
    with_page(<<~HTML) do |page|
      <input id="field"><output id="events"></output>
      <script>
        const field = document.querySelector("#field");
        field.addEventListener("keydown", e => {
          if (e.key === "x") e.preventDefault();
          document.querySelector("#events").textContent += e.key + ";";
        });
      </script>
    HTML
      field = page.find(:css, "#field")
      field.send_keys("abx", :left, "Z", :end, :backspace)
      assert_equal "aZ", field.value
      assert_equal "a;b;x;ArrowLeft;Z;End;Backspace;", page.find(:css, "#events").text
      assert_raises(Capybara::NotSupportedByDriverError) { field.send_keys([:control, "a"]) }
    end
  end

  def test_binary_multipart_fetch_from_attached_file
    skip "File inputs require Node/jsdom" if ENV["DOMSTRIDE_ENGINE"] == "happy-dom" || ENV["DOMSTRIDE_RUNTIME"] == "bun"
    contents = [0, 255, 128, 65, 10].pack("C*")
    received = []
    html = <<~HTML
      <form id="form"><input name="description" value="Receipt"><input id="file" name="receipt" type="file"></form>
      <button id="upload">Upload</button><output id="result">Pending</output>
      <script>
        document.querySelector("#upload").onclick = async () => {
          const response = await fetch("/upload", {method: "POST", body: new FormData(document.querySelector("#form"))});
          document.querySelector("#result").textContent = await response.text();
        };
      </script>
    HTML
    app = lambda do |env|
      if env["PATH_INFO"] == "/"
        [200, {"content-type" => "text/html"}, [html]]
      else
        params = Rack::Request.new(env).POST
        file = params.fetch("receipt")
        received << [params.fetch("description"), file.fetch(:filename), file.fetch(:tempfile).read.b]
        file.fetch(:tempfile).close!
        [200, {"content-type" => "text/plain"}, ["Saved"]]
      end
    end
    Tempfile.create(["receipt", ".bin"]) do |file|
      file.binmode
      file.write(contents)
      file.flush
      with_page(html, app: app) do |page|
        page.find(:css, "#file").set(file.path)
        assert_equal File.basename(file.path), page.evaluate_script('document.querySelector("#file").files[0].name')
        page.find(:css, "#upload").click
        assert page.has_css?("#result", exact_text: "Saved")
        assert_equal [["Receipt", File.basename(file.path), contents]], received
      end
    end
  end
end
