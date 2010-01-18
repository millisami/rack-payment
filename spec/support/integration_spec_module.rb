# Helper to include the things we need to include in a 
# describe block to web Webrat and whatnot
module IntegrationSpec
  def self.included base
    base.send :include, Webrat::Matchers
    base.send :include, Webrat::Methods
    base.send :include, Rack::Test::Methods
  end
end
