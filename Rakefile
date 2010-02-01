desc 'Runs specs'
task :spec do
  dir = File.dirname(__FILE__)
  system 'gem bundle'
  exec "#{ dir }/vendor/bin/spec -c -f specdoc #{ dir }/spec"
end

desc 'Runs specs (default)'
task :default => :spec
