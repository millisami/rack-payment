Gem::Specification.new do |s|
  s.name        = 'rack-payment'
  s.version     = '0.1.0'
  s.summary     = 'Turn-key E-Commerce for Ruby web applications'
  s.description = 'Turn-key E-Commerce for Ruby web applications'
  s.files       = Dir['lib/**/*']
  s.author      = 'remi'
  s.email       = 'remi@remitaylor.com'
  s.homepage    = 'http://github.com/devfu/rack-payment'

  s.add_dependency 'activemerchant'
end
