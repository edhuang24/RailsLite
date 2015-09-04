require 'json'
require 'webrick'
require 'active_support'
require 'active_support/inflector'
require 'active_support/core_ext'
require 'erb'

class ControllerBase
  attr_reader :req, :res, :params

  # Setup the controller
  def initialize(req, res)
    @req = req
    @res = res
  end

  # Helper method to alias @already_built_response
  def already_built_response?
    @already_built_response
  end

  # Set the response status code and header
  def redirect_to(url)
    if !already_built_response?
      @res["location"] = url
      @res.status = 302
      @already_built_response = true
    else
      raise "exception"
    end
    session.store_session(res)
    # storing the flash will fail the last spec
    flash.store_flash(res)
  end

  # Populate the response with content.
  # Set the response's content type to the given type.
  # Raise an error if the developer tries to double render.
  def render_content(content, content_type)
    if !already_built_response?
      @res.body = content
      @res.content_type = content_type
      @already_built_response = true
    else
      raise "exception"
    end
    session.store_session(res)
    # storing the flash will fail the last spec
    flash.store_flash(res)
  end

  # use ERB and binding to evaluate templates
  # pass the rendered html to render_content
  def render(template_name)
    contents = File.read("views/#{self.class.to_s.underscore}/#{template_name}.html.erb")
    template = ERB.new(contents)
    # ivars = self.instance_variables
    new_content = template.result(binding)
    render_content(new_content, "text/html")
  end

  # method exposing a `Session` object
  def session
    @session ||= Session.new(req)
  end

  def flash
    @flash ||= Flash.new(req)
  end

  # setup the controller
  def initialize(req, res, route_params = {})
    @params = Params.new(req, route_params)
    @req = req
    @res = res
  end

  # use this with the router to call action_name (:index, :show, :create...)
  def invoke_action(name)
    send(name)
    render(name) unless already_built_response?
  end
end

class Session
  # find the cookie for this app
  # deserialize the cookie into a hash
  def initialize(req)
    @session = {}
    req.cookies.each do |cookie|
      @session = JSON.parse(cookie.value) if cookie.name == '_rails_lite_app'
    end
  end

  def [](key)
    @session[key]
  end

  def []=(key, val)
    @session[key] = val
  end

  # serialize the hash into json and save in a cookie
  # add to the responses cookies
  def store_session(res)
    cookie = WEBrick::Cookie.new('_rails_lite_app', @session.to_json)
    res.cookies << cookie
  end
end

class Flash
  attr_reader :flash

  def initialize(req)
    @later = {}
    @now = {}
    req.cookies.each do |cookie|
      @later = JSON.parse(cookie.value) if cookie.name == 'later'
    end
  end

  def [](key)
    @now[key.to_sym] || @later[key.to_sym] || @now[key.to_s] || @later[key.to_s]
  end

  def []=(key, val)
    @later[key] = val
  end

  def store_flash(res)
    cookie = WEBrick::Cookie.new('later', @later.to_json)
    res.cookies << cookie
  end

  def now
    @now
  end
end

class Params
  # use your initialize to merge params from
  # 1. query string
  # 2. post body
  # 3. route params
  #
  # You haven't done routing yet; but assume route params will be
  # passed in as a hash to `Params.new` as below:
  def initialize(req, route_params = {})
    @params = route_params
    @params.merge! parse_www_encoded_form(req.query_string) unless req.query_string.nil?
    @params.merge! parse_www_encoded_form(req.body) unless req.body.nil?
  end

  def [](key)
    @params[key.to_s] || @params[key.to_sym]
  end

  # this will be useful if we want to `puts params` in the server log
  def to_s
    @params.to_s
  end

  class AttributeNotFoundError < ArgumentError; end;

  private
  # this should return deeply nested hash
  # argument format
  # user[address][street]=main&user[address][zip]=89436
  # should return
  # { "user" => { "address" => { "street" => "main", "zip" => "89436" } } }
  def parse_www_encoded_form(www_encoded_form)
    params = {}
    URI::decode_www_form(www_encoded_form).each do |el|
      current = params
      keys = parse_key(el.first)
      value = el.last
      keys[0...-1].each_with_index do |key, i|
        current[key] ||= {}
        current = current[key]
      end
      current[keys.last] = el.last
    end
    params
  end

  # def parse_www_encoded_form(www_encoded_form)
  #   decoded = URI::decode_www_form(www_encoded_form)
  #   params = {}
  #   decoded.each do |key, value|
  #     current = params
  #     keys = parse_key(key)
  #     keys[0...-1].each_with_index do |key, i|
  #       current[key] ||= {}
  #       current = current[key]
  #     end
  #     current[keys.last] = value
  #   end
  #   params
  # end

  # this should return an array
  # user[address][street] should return ['user', 'address', 'street']
  def parse_key(key)
    key.split(/\]\[|\[|\]/)
  end
end

class Route
  attr_reader :pattern, :http_method, :controller_class, :action_name

  def initialize(pattern, http_method, controller_class, action_name)
    @pattern, @http_method, @controller_class, @action_name = pattern, http_method, controller_class, action_name
  end

  # checks if pattern matches path and method matches request method
  def matches?(req)
    req.path =~ pattern && http_method == req.request_method.downcase.to_sym
  end

  # use pattern to pull out route params (save for later?)
  # instantiate controller and call controller action
  def run(req, res)
    match_data = pattern.match(req.path)
    # hash = {}
    # match_data.names.each do |name|
    #   hash[name] = match_data[name]
    # end
    hash = match_data.names.each_with_object({}) do |name, h|
      h[name] = match_data[name]
    end
    controller_class.new(req, res, hash).invoke_action(action_name)
  end
end

class Router
  attr_reader :routes

  def initialize
    @routes = []
  end

  # simply adds a new route to the list of routes
  def add_route(pattern, method, controller_class, action_name)
    @routes << Route.new(pattern, method, controller_class, action_name)
  end

  # evaluate the proc in the context of the instance
  # for syntactic sugar :)
  def draw(&proc)
    self.instance_eval(&proc)
    # self.instance_eval { proc.call }
  end

  # make each of these methods that
  # when called add route
  [:get, :post, :put, :delete].each do |http_method|
    define_method(http_method) do |pattern, controller_class, action_name|
      add_route(pattern, http_method, controller_class, action_name)
    end
  end

  # should return the route that matches this request
  def match(req)
    # @routes.each do |route|
    #   return route if route.matches?(req)
    # end
    #
    # nil
    @routes.find { |route| route.matches?(req) }
  end

  # either throw 404 or call run on a matched route
  def run(req, res)
    if match(req).nil?
      res.status = 404
    else
      match(req).run(req, res)
    end
  end
end
