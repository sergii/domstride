require_relative "../lib/domstride"

Domstride::Session.open do |page|
  page.mount_html(File.read(File.join(__dir__, "counter.html")))
  page.click("#increment")
  page.assert_text("#count", "1")
  puts "Counter interaction passed"
end
