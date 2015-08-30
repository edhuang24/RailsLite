require 'webrick'

# http://www.ruby-doc.org/stdlib-2.0/libdoc/webrick/rdoc/WEBrick.html
# http://www.ruby-doc.org/stdlib-2.0/libdoc/webrick/rdoc/WEBrick/HTTPRequest.html
# http://www.ruby-doc.org/stdlib-2.0/libdoc/webrick/rdoc/WEBrick/HTTPResponse.html
# http://www.ruby-doc.org/stdlib-2.0/libdoc/webrick/rdoc/WEBrick/Cookie.html
server = WEBrick::HTTPServer.new(Port: 3000)

# server.mount_proc('/') do |req, res|
#   res.status = 20
#   if req.query['name']
#     name = req.query['name']
#     res.cookies << WEBrick::Cookie.new('_demo_app', { name: name }.to_json )
#   else
#     name = "Random Name"
#   end
# end

server.mount_proc("/") do |request, response|
  response.status = 20

  if request.path
    name = request.path
  else
    name = "Random Name"
  end
  response.body = "Hi, #{name}"
  # response.content_type = "text/text"
  # response.body = "I love App Academy!"
end

trap('INT') { server.shutdown }

server.start
