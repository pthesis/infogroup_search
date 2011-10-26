# -*- encoding: utf-8 -*-
# $LOAD_PATH.unshift File.expand_path('../lib', __FILE__)

Gem::Specification.new do |s|
  s.name        = "infogroup_search"
  s.version     = "0.4"
  s.platform    = Gem::Platform::RUBY
  s.authors = ["Jason May"]
  s.email = %q{jason.may@infogroup.com}
  s.date = %q{2011-10-10}
  s.homepage    = "http://github.com/infogroup/infogroup_search"
  s.summary = %q{Ruby interface to Infogroup Consumer & Business search.}

  s.required_rubygems_version = ">= 1.6.3"
  s.rubyforge_project         = ""

  s.add_development_dependency "bundler", ">= 1.0.12"

  s.files        = `git ls-files`.split("\n")
  s.executables  = `git ls-files`.split("\n").select{|f| f =~ /^bin/}.map{|f| f.gsub(/^bin/, '')}
  s.require_path = 'lib'
end
