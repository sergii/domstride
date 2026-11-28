require "minitest/autorun"
require "pathname"
require "tempfile"
require "rack"
require "specdrive/capybara"

class TestbenchMultipartContractTest < Minitest::Test
  HTML = <<~HTML
    <!doctype html>
    <form id="note" enctype="multipart/form-data">
      <label for="body">Note body</label><input id="body" name="body">
      <label for="document">Document</label><input id="document" type="file" name="document">
      <button type="submit">Create note</button>
    </form>
    <p id="result"></p>
    <script>
      document.getElementById("note").addEventListener("submit", async event => {
        event.preventDefault();
        const response = await fetch("/notes", {method: "POST", body: new FormData(event.target)});
        document.getElementById("result").textContent = await response.text();
      });
    </script>
  HTML

  def setup
    Capybara.register_driver(:specdrive_multipart_contract) do |app|
      Specdrive::CapybaraAdapter::Driver.new(app, engine: "jsdom31", runtime: "node")
    end
    app = lambda do |env|
      request = Rack::Request.new(env)
      if request.post?
        params = request.POST
        file = params["document"]
        text = if file.nil?
          "#{params.fetch('body')}|no upload"
        else
          "#{params.fetch('body')}|#{file.fetch(:filename)}|#{file.fetch(:tempfile).read}"
        end
        [200, {"content-type" => "text/plain"}, [text]]
      else
        [200, {"content-type" => "text/html"}, [HTML]]
      end
    end
    @page = Capybara::Session.new(:specdrive_multipart_contract, app)
  end

  def teardown
    @page&.driver&.quit
  end

  def test_optional_file_input_does_not_create_phantom_upload
    @page.visit("/")
    @page.fill_in("Note body", with: "note")
    @page.click_button("Create note")
    assert @page.has_css?("#result", text: "note|no upload")
  end

  def test_pathname_upload_preserves_filename_and_bytes
    Tempfile.create(["customer-note", ".txt"]) do |file|
      file.write("document contents")
      file.flush
      @page.visit("/")
      @page.fill_in("Note body", with: "note")
      @page.attach_file("Document", Pathname.new(file.path))
      @page.click_button("Create note")
      assert @page.has_css?("#result", text: "note|#{File.basename(file.path)}|document contents")
    end
  end

  def test_named_empty_file_is_not_dropped
    Tempfile.create(["empty-note", ".txt"]) do |file|
      @page.visit("/")
      @page.fill_in("Note body", with: "note")
      @page.attach_file("Document", file.path)
      @page.click_button("Create note")
      assert @page.has_css?("#result", text: "note|#{File.basename(file.path)}|")
    end
  end
end
