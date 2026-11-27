require "minitest/autorun"
require "domstride/report"

class VideoCueTest < Minitest::Test
  def test_export_validates_cue_references
    Dir.mktmpdir do |dir|
      file = File.join(dir,"source.webm")
      File.binwrite(file,"\x1a\x45\xdf\xa3\x42\x82\x84webm".b)
      root = File.join(dir,"cases")
      Domstride::Report.capture(directory: root,name: "Mapped case") do |item|
        item.start_step(keyword: "Given")
        item.finish_step("passed")
        Domstride::Video.attach(file,cues: [{kind: "step",sequence: 1,time_ms: 125.5}])
      end
      assert_includes File.read(Domstride::Report.export(root)), '"time_ms":125.5'
      meta = Dir[File.join(root,"domstride-case-*","case.json")].first
      item = JSON.parse(File.read(meta))
      item["videos"][0]["focus"] = [{ "kind"=>"fill","status"=>"passed","start_ms"=>0,"end_ms"=>500,"x"=>0.9,"y"=>0.1,"width"=>0.2,"height"=>0.1 }]
      File.write(meta,JSON.generate(item))
      assert_raises(Domstride::Error) { Domstride::Report.export(root,output: File.join(root,"bad-focus.html")) }
      item["videos"][0].delete("focus")
      item["videos"][0]["cues"][0]["sequence"] = 99
      File.write(meta,JSON.generate(item))
      assert_raises(Domstride::Error) { Domstride::Report.export(root,output: File.join(root,"invalid.html")) }
    end
  end
end
