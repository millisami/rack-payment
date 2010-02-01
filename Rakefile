desc 'Runs specs'
task :spec do
  system 'gem bundle'
  exec "spec -c -f specdoc #{ File.dirname(__FILE__) + '/spec' }"
end

desc 'Runs specs (default)'
task :default => :spec
