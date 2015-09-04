require 'webrick'
require_relative '../lib/controller_base'

describe ControllerBase do
  before(:all) do
    class UsersController < ControllerBase
      def index
      end
    end
  end
  after(:all) { Object.send(:remove_const, "UsersController") }

  let(:req) { WEBrick::HTTPRequest.new(Logger: nil) }
  let(:res) { WEBrick::HTTPResponse.new(HTTPVersion: '1.0') }
  let(:users_controller) { UsersController.new(req, res) }

  describe "#render_content" do
    before(:each) do
      users_controller.render_content "somebody", "text/html"
    end

    it "sets the response content type" do
      expect(users_controller.res.content_type).to eq("text/html")
    end

    it "sets the response body" do
      expect(users_controller.res.body).to eq("somebody")
    end

    describe "#already_built_response?" do
      let(:users_controller2) { UsersController.new(req, res) }

      it "is false before rendering" do
        expect(users_controller2.already_built_response?).to be_falsey
      end

      it "is true after rendering content" do
        users_controller2.render_content "sombody", "text/html"
        expect(users_controller2.already_built_response?).to be_truthy
      end

      it "raises an error when attempting to render twice" do
        users_controller2.render_content "sombody", "text/html"
        expect do
          users_controller2.render_content "sombody", "text/html"
        end.to raise_error
      end
    end
  end

  describe "#redirect" do
    before(:each) do
      users_controller.redirect_to("http://www.google.com")
    end

    it "sets the header" do
      expect(users_controller.res.header["location"]).to eq("http://www.google.com")
    end

    it "sets the status" do
      expect(users_controller.res.status).to eq(302)
    end

    describe "#already_built_response?" do
      let(:users_controller2) { UsersController.new(req, res) }

      it "is false before rendering" do
        expect(users_controller2.already_built_response?).to be_falsey
      end

      it "is true after rendering content" do
        users_controller2.redirect_to("http://google.com")
        expect(users_controller2.already_built_response?).to be_truthy
      end

      it "raises an error when attempting to render twice" do
        users_controller2.redirect_to("http://google.com")
        expect do
          users_controller2.redirect_to("http://google.com")
        end.to raise_error
      end
    end
  end
end

describe ControllerBase do
  before(:all) do
    class CatsController < ControllerBase
      def index
        @cats = ["GIZMO"]
      end
    end
  end
  after(:all) { Object.send(:remove_const, "CatsController") }

  let(:req) { WEBrick::HTTPRequest.new(Logger: nil) }
  let(:res) { WEBrick::HTTPResponse.new(HTTPVersion: '1.0') }
  let(:cats_controller) { CatsController.new(req, res) }

  describe "#render" do
    before(:each) do
      cats_controller.render(:index)
    end

    it "renders the html of the index view" do
      expect(cats_controller.res.body).to include("ALL THE CATS")
      expect(cats_controller.res.body).to include("<h1>")
      expect(cats_controller.res.content_type).to eq("text/html")
    end

    describe "#already_built_response?" do
      let(:cats_controller2) { CatsController.new(req, res) }

      it "is false before rendering" do
        expect(cats_controller2.already_built_response?).to be_falsey
      end

      it "is true after rendering content" do
        cats_controller2.render(:index)
        expect(cats_controller2.already_built_response?).to be_truthy
      end

      it "raises an error when attempting to render twice" do
        cats_controller2.render(:index)
        expect do
          cats_controller2.render(:index)
        end.to raise_error
      end
    end
  end
end

describe Session do
  let(:req) { WEBrick::HTTPRequest.new(Logger: nil) }
  let(:res) { WEBrick::HTTPResponse.new(HTTPVersion: '1.0') }
  let(:cook) { WEBrick::Cookie.new('_rails_lite_app', { xyz: 'abc' }.to_json) }

  it "deserializes json cookie if one exists" do
    req.cookies << cook
    session = Session.new(req)
    expect(session['xyz']).to eq('abc')
  end

  describe "#store_session" do
    context "without cookies in request" do
      before(:each) do
        session = Session.new(req)
        session['first_key'] = 'first_val'
        session.store_session(res)
      end

      it "adds new cookie with '_rails_lite_app' name to response" do
        cookie = res.cookies.find { |c| c.name == '_rails_lite_app' }
        expect(cookie).not_to be_nil
      end

      it "stores the cookie in json format" do
        cookie = res.cookies.find { |c| c.name == '_rails_lite_app' }
        expect(JSON.parse(cookie.value)).to be_instance_of(Hash)
      end
    end

    context "with cookies in request" do
      before(:each) do
        cook = WEBrick::Cookie.new('_rails_lite_app', { pho: "soup" }.to_json)
        req.cookies << cook
      end

      it "reads the pre-existing cookie data into hash" do
        session = Session.new(req)
        expect(session['pho']).to eq('soup')
      end

      it "saves new and old data to the cookie" do
        session = Session.new(req)
        session['machine'] = 'mocha'
        session.store_session(res)
        cookie = res.cookies.find { |c| c.name == '_rails_lite_app' }
        h = JSON.parse(cookie.value)
        expect(h['pho']).to eq('soup')
        expect(h['machine']).to eq('mocha')
      end
    end
  end
end

describe ControllerBase do
  before(:all) do
    class CatsController < ControllerBase
    end
  end
  after(:all) { Object.send(:remove_const, "CatsController") }

  let(:req) { WEBrick::HTTPRequest.new(Logger: nil) }
  let(:res) { WEBrick::HTTPResponse.new(HTTPVersion: '1.0') }
  let(:cats_controller) { CatsController.new(req, res) }

  describe "#session" do
    it "returns a session instance" do
      expect(cats_controller.session).to be_a(Session)
    end

    it "returns the same instance on successive invocations" do
      first_result = cats_controller.session
      expect(cats_controller.session).to be(first_result)
    end
  end

  shared_examples_for "storing session data" do
    it "should store the session data" do
      cats_controller.session['test_key'] = 'test_value'
      cats_controller.send(method, *args)
      cookie = res.cookies.find { |c| c.name == '_rails_lite_app' }
      h = JSON.parse(cookie.value)
      expect(h['test_key']).to eq('test_value')
    end
  end

  describe "#render_content" do
    let(:method) { :render_content }
    let(:args) { ['test', 'text/plain'] }
    include_examples "storing session data"
  end

  describe "#redirect_to" do
    let(:method) { :redirect_to }
    let(:args) { ['http://appacademy.io'] }
    include_examples "storing session data"
  end
end

describe Params do
  before(:all) do
    class CatsController < ControllerBase
      def index
        @cats = ["Gizmo"]
      end
    end
  end
  after(:all) { Object.send(:remove_const, "CatsController") }

  let(:req) { WEBrick::HTTPRequest.new(Logger: nil) }
  let(:res) { WEBrick::HTTPResponse.new(HTTPVersion: '1.0') }
  let(:cats_controller) { CatsController.new(req, res) }

  it "handles an empty request" do
    expect { Params.new(req) }.to_not raise_error
  end

  context "query string" do
    it "handles single key and value" do
      req.query_string = "key=val"
      params = Params.new(req)
      expect(params["key"]).to eq("val")
    end

    it "handles multiple keys and values" do
      req.query_string = "key=val&key2=val2"
      params = Params.new(req)
      expect(params["key"]).to eq("val")
      expect(params["key2"]).to eq("val2")
    end

    it "handles nested keys" do
      req.query_string = "user[address][street]=main"
      params = Params.new(req)
      expect(params["user"]["address"]["street"]).to eq("main")
    end

    it "handles multiple nested keys and values" do
      req.query_string =  "user[fname]=rebecca&user[lname]=smith"
      params = Params.new(req)
      expect(params["user"]["fname"]).to eq("rebecca")
      expect(params["user"]["lname"]).to eq("smith")
    end
  end

  context "post body" do
    it "handles single key and value" do
      allow(req).to receive(:body) { "key=val" }
      params = Params.new(req)
      expect(params["key"]).to eq("val")
    end

    it "handles multiple keys and values" do
      allow(req).to receive(:body) { "key=val&key2=val2" }
      params = Params.new(req)
      expect(params["key"]).to eq("val")
      expect(params["key2"]).to eq("val2")
    end

    it "handles nested keys" do
      allow(req).to receive(:body) { "user[address][street]=main" }
      params = Params.new(req)
      expect(params["user"]["address"]["street"]).to eq("main")
    end

    it "handles multiple nested keys and values" do
      allow(req).to receive(:body) { "user[fname]=rebecca&user[lname]=smith" }
      params = Params.new(req)
      expect(params["user"]["fname"]).to eq("rebecca")
      expect(params["user"]["lname"]).to eq("smith")
    end
  end

  context "route params" do
    it "handles route params" do
      params = Params.new(req, {"id" => 5, "user_id" => 22})
      expect(params["id"]).to eq(5)
      expect(params["user_id"]).to eq(22)
    end
  end

  context "indifferent access" do
    it "responds to string and symbol keys when stored as a string" do
      params = Params.new(req, {"id" => 5})
      expect(params["id"]).to eq(5)
      expect(params[:id]).to eq(5)
    end
    it "responds to string and symbol keys when stored as a symbol" do
      params = Params.new(req, {:id => 5})
      expect(params["id"]).to eq(5)
      expect(params[:id]).to eq(5)
    end
  end

  # describe "strong parameters" do
  #   describe "#permit" do
  #     it "allows the permitting of multiple attributes" do
  #       req.query_string = "key=val&key2=val2&key3=val3"
  #       params = Params.new(req)
  #       params.permit("key", "key2")
  #       expect(params.permitted?("key")).to be_truthy
  #       expect(params.permitted?("key2")).to be_truthy
  #       expect(params.permitted?("key3")).to be_falsey
  #     end
  #
  #     it "collects up permitted keys across multiple calls" do
  #       req.query_string = "key=val&key2=val2&key3=val3"
  #       params = Params.new(req)
  #       params.permit("key")
  #       params.permit("key2")
  #       expect(params.permitted?("key")).to be_truthy
  #       expect(params.permitted?("key2")).to be_truthy
  #       expect(params.permitted?("key3")).to be_falsey
  #     end
  #   end
  #
  #   describe "#require" do
  #     it "throws an error if the attribute does not exist" do
  #       req.query_string = "key=val"
  #       params = Params.new(req)
  #       expect { params.require("key") }.to_not raise_error
  #       expect { params.require("key2") }.to raise_error(Params::AttributeNotFoundError)
  #     end
  #   end
  #
  #   describe "interaction with ARLite models" do
  #     it "throws a ForbiddenAttributesError if mass assignment is attempted with unpermitted attributes" do
  #
  #     end
  #   end
  # end
end

describe Route do
  let(:req) { WEBrick::HTTPRequest.new(Logger: nil) }
  let(:res) { WEBrick::HTTPResponse.new(HTTPVersion: '1.0') }

  before(:each) do
    allow(req).to receive(:request_method).and_return("GET")
  end

  describe "#matches?" do
    it "matches simple regular expression" do
      index_route = Route.new(Regexp.new("^/users$"), :get, "x", :x)
      allow(req).to receive(:path) { "/users" }
      allow(req).to receive(:request_method) { :get }
      expect(index_route.matches?(req)).to be_truthy
    end

    it "matches regular expression with capture" do
      index_route = Route.new(Regexp.new("^/users/(?<id>\\d+)$"), :get, "x", :x)
      allow(req).to receive(:path) { "/users/1" }
      allow(req).to receive(:request_method) { :get }
      expect(index_route.matches?(req)).to be_truthy
    end

    it "correctly doesn't matche regular expression with capture" do
      index_route = Route.new(Regexp.new("^/users/(?<id>\\d+)$"), :get, "UsersController", :index)
      allow(req).to receive(:path) { "/statuses/1" }
      allow(req).to receive(:request_method) { :get }
      expect(index_route.matches?(req)).to be_falsey
    end
  end

  describe "#run" do
    before(:all) { class DummyController; end }
    after(:all) { Object.send(:remove_const, "DummyController") }

    it "instantiates controller and invokes action" do
      # reader beware. hairy adventures ahead.
      # this is really checking way too much implementation,
      # but tests the aproach recommended in the project
      allow(req).to receive(:path) { "/users" }

      dummy_controller_class = DummyController
      dummy_controller_instance = DummyController.new
      allow(dummy_controller_instance).to receive(:invoke_action)
      allow(dummy_controller_class).to receive(:new).with(req, res, {}) do
        dummy_controller_instance
      end
      expect(dummy_controller_instance).to receive(:invoke_action)
      index_route = Route.new(Regexp.new("^/users$"), :get, dummy_controller_class, :index)
      index_route.run(req, res)
    end
  end
end

describe Router do
  let(:req) { WEBrick::HTTPRequest.new(Logger: nil) }
  let(:res) { WEBrick::HTTPResponse.new(HTTPVersion: '1.0') }

  describe "#add_route" do
    it "adds a route" do
      subject.add_route(1, 2, 3, 4)
      expect(subject.routes.count).to eq(1)
      subject.add_route(1, 2, 3, 4)
      subject.add_route(1, 2, 3, 4)
      expect(subject.routes.count).to eq(3)
    end
  end

  describe "#match" do
    it "matches a correct route" do
      subject.add_route(Regexp.new("^/users$"), :get, :x, :x)
      allow(req).to receive(:path) { "/users" }
      allow(req).to receive(:request_method) { :get }
      matched = subject.match(req)
      expect(matched).not_to be_nil
    end

    it "doesn't match an incorrect route" do
      subject.add_route(Regexp.new("^/users$"), :get, :x, :x)
      allow(req).to receive(:path) { "/incorrect_path" }
      allow(req).to receive(:request_method) { :get }
      matched = subject.match(req)
      expect(matched).to be_nil
    end
  end

  describe "#run" do
    it "sets status to 404 if no route is found" do
      subject.add_route(Regexp.new("^/users$"), :get, :x, :x)
      allow(req).to receive(:path).and_return("/incorrect_path")
      allow(req).to receive(:request_method).and_return("GET")
      subject.run(req, res)
      expect(res.status).to eq(404)
    end
  end

  describe "http method (get, put, post, delete)" do
    it "adds methods get, put, post and delete" do
      router = Router.new
      expect((router.methods - Class.new.methods)).to include(:get)
      expect((router.methods - Class.new.methods)).to include(:put)
      expect((router.methods - Class.new.methods)).to include(:post)
      expect((router.methods - Class.new.methods)).to include(:delete)
    end

    it "adds a route when an http method method is called" do
      router = Router.new
      router.get Regexp.new("^/users$"), ControllerBase, :index
      expect(router.routes.count).to eq(1)
    end
  end
end

describe "the symphony of things" do
  let(:req) { WEBrick::HTTPRequest.new(Logger: nil) }
  let(:res) { WEBrick::HTTPResponse.new(HTTPVersion: '1.0') }

  before(:all) do
    class Ctrlr < ControllerBase
      def route_render
        render_content("testing", "text/html")
      end

      def route_does_params
        render_content("got ##{ params["id"] }", "text/text")
      end

      def update_session
        session[:token] = "testing"
        render_content("hi", "text/html")
      end
    end
  end
  after(:all) { Object.send(:remove_const, "Ctrlr") }

  describe "routes and params" do
    it "route instantiates controller and calls invoke action" do
      route = Route.new(Regexp.new("^/statuses/(?<id>\\d+)$"), :get, Ctrlr, :route_render)
      allow(req).to receive(:path) { "/statuses/1" }
      allow(req).to receive(:request_method) { :get }
      route.run(req, res)
      expect(res.body).to eq("testing")
    end

    it "route adds to params" do
      route = Route.new(Regexp.new("^/statuses/(?<id>\\d+)$"), :get, Ctrlr, :route_does_params)
      allow(req).to receive(:path) { "/statuses/1" }
      allow(req).to receive(:request_method) { :get }
      route.run(req, res)
      expect(res.body).to eq("got #1")
    end
  end

  describe "controller sessions" do
    let(:ctrlr) { Ctrlr.new(req, res) }

    it "exposes a session via the session method" do
      expect(ctrlr.session).to be_instance_of(Session)
    end

    it "saves the session after rendering content" do
      ctrlr.update_session
      # Currently broken when flash is used. Need to store flash in the cookie
      # or change this spec.
      expect(res.cookies.count).to eq(1)
      expect(JSON.parse(res.cookies[0].value)["token"]).to eq("testing")
    end
  end
end


