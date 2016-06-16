require 'mechanize'

begin
  Dir.mkdir './output'
rescue
end

a = Mechanize.new
baseUrl = 'http://fastdl.gflclan.com/csgo/maps/'
page = a.get(baseUrl)

page.links.each  do |link|
  if link.href.start_with? "surf_"
    p link.href
    linkUrl = baseUrl + link.href
    `wget -O ./output/#{link.href} \"#{linkUrl}\"`
  end
end

