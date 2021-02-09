Gem::Specification.new do |spec|
  spec.name        = 'samizdat'
  spec.version     = '0.7.1'
  spec.author      = 'Dmitry Borodaenko'
  spec.email       = 'angdraug@debian.org'
  spec.homepage    = 'https://github.com/angdraug/samizdat'
  spec.summary     = 'Web collaboration and open publishing engine'
  spec.description = <<-EOF
Generic RDF-based Web engine intended for building collaboration and open
publishing web sites. Samizdat engine allows everyone to publish, view,
comment, edit, and aggregate text and multimedia resources, vote on ratings
and classifications, filter resources by flexible sets of criteria.
    EOF
  spec.files       = %w(AUTHORS COPYING ChangeLog.mtn ChangeLog.cvs README NEWS
                        TODO setup.rb Rakefile samizdat.gemspec) +
                     Dir['{lib,test}/**/*.rb'] +
                     Dir['doc/**/*.{txt,tex,yaml,sql,svg}'] +
                     Dir['{bin,cgi-bin,data/**/*']
  spec.test_files  = Dir['test/ts_*.rb']
  spec.license     = 'GPL-3.0+'
  spec.add_dependency 'graffiti'
  spec.add_dependency 'magic'
  spec.add_dependency 'rack'
  spec.add_dependency 'rmagick'
  spec.add_dependency 'whitewash'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'test-unit'
  spec.add_development_dependency 'fast-gettext'
  spec.add_development_dependency 'tzinfo'
end
