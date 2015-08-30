require 'webrick'
require_relative '../lib/controller_base'
require 'byebug'

# http://www.ruby-doc.org/stdlib-2.0/libdoc/webrick/rdoc/WEBrick.html
# http://www.ruby-doc.org/stdlib-2.0/libdoc/webrick/rdoc/WEBrick/HTTPRequest.html
# http://www.ruby-doc.org/stdlib-2.0/libdoc/webrick/rdoc/WEBrick/HTTPResponse.html
# http://www.ruby-doc.org/stdlib-2.0/libdoc/webrick/rdoc/WEBrick/Cookie.html

$cats = [
  { id: 1, name: "Curie" },
  { id: 2, name: "Markov" }
]

$statuses = [
  { id: 1, cat_id: 1, text: "Curie loves string!" },
  { id: 2, cat_id: 2, text: "Markov is mighty!" },
  { id: 3, cat_id: 1, text: "Curie is cool!" }
]

class Cat
  attr_reader :name, :owner

  def self.all
    @cat ||= []
  end

  def initialize(params = {})
    params ||= {}
    @name, @owner = params["name"], params["owner"]
  end

  def save
    return false unless @name.present? && @owner.present?

    Cat.all << self
    true
  end

  def inspect
    { name: name, owner: owner }.inspect
  end
end

class StatusesController < ControllerBase
  def index
    statuses = $statuses.select do |s|
      s[:cat_id] == Integer(params[:cat_id])
    end

    render_content(statuses.to_s, "text/text")
  end
end

class CatsController < ControllerBase
  def create
    @cat = Cat.new(params["cat"])
    if @cat.save
      flash[:errors] = ["invalid"]
      # debugger
      redirect_to("/cats")
    else
      flash.now[:errors] = ["invalid login credentials"]
      render :new
    end
  end

  def index
    @cats = Cat.all
    render :index
  end

  def new
    @cat = Cat.new
    render :new
  end
end

# router = Router.new
# router.draw do
#   get Regexp.new("^/cats$"), CatsController, :index
#   get Regexp.new("^/cats/(?<cat_id>\\d+)/statuses$"), StatusesController, :index
# end

server = WEBrick::HTTPServer.new(Port: 3000)
server.mount_proc('/') do |req, res|
  case [req.request_method, req.path]
  when ['GET', '/cats']
    CatsController.new(req, res, {}).index
  when ['POST', '/cats']
    CatsController.new(req, res, {}).create
  when ['GET', '/cats/new']
    CatsController.new(req, res, {}).new
  end
end

trap('INT') { server.shutdown }
server.start
