# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_rails-example_session',
  :secret      => '9670b3c3e9fbf7f8b20410c3425ad05eab5c5367045a2f9cf772de84ae71731bf3051b90f08a273a4e3ef6e2c1dfe0a5d19002ab9cf6a5953e2f17648f9d8195'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
