# extension to Rack::Test so it's easy to change the 'current' Rack application
module Rack::Test::Methods

  def build_rack_mock_session
    # Rack::MockSession.new(app) # <--- original code merely calls 'app'
    Rack::MockSession.new(@_rack_app || app)
  end

  def set_rack_app app
    @_rack_app = app
    @_rack_mock_sessions = { :default => build_rack_mock_session }
  end

end
