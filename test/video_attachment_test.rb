require "minitest/autorun"
require "domstride"
require "domstride/report"

class VideoAttachmentTest < Minitest::Test
  # A minimal header fixture only tests importer bounds, not video decoding.
  HEADER = "\x1a\x45\xdf\xa3\x42\x82\x84webm".b

  def test_video_attachment_policy
    Dir.mktmpdir do |dir|
      source = File.join(dir, "fixture.webm")
      File.binwrite(source, HEADER)
      root = File.join(dir,"cases")
      assert_raises(Domstride::Error) { Domstride::Video.attach(source) }
      Domstride::Report.capture(directory: root, name: "Browser case") do |item|
        assert_equal "video-01.webm", Domstride::Video.attach(source, label: "Chromium")
        assert_equal 0o600, File.stat(File.join(item.path,"video-01.webm")).mode & 0o777
        link = File.join(dir,"link.webm")
        File.symlink(source, link)
        assert_raises(Domstride::Error) { Domstride::Video.attach(link) }
        File.binwrite(source,"not video")
        assert_raises(Domstride::Error) { Domstride::Video.attach(source) }
        File.open(source,"wb") { |file| file.truncate(Domstride::Video::MAX_BYTES + 1) }
        assert_raises(Domstride::Error) { Domstride::Video.attach(source) }
      end
      html = File.read(Domstride::Report.export(root))
      json = html.split('<script type="application/json" id="recording-data">',2).last.split("</script>",2).first
      item = JSON.parse(json).fetch("cases").first
      assert_equal "passed", item["status"]
      assert_equal "Chromium", item.fetch("videos").first["label"]
      assert_equal HEADER, Base64.strict_decode64(item.fetch("videos").first["base64"])
      assert_empty item["recordings"]
    end
  end
end
