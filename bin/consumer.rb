#!/usr/bin/env ruby

require "ap"
require "trollop"
require "redis"
load "#{File.dirname(__FILE__)}/../lib/infogroup_search.rb"


opts = Trollop::options do
  opt :env, "Environment", :type => :string, :default => "test"
  opt :format, "Results in XML", :default => "json"
  opt :debug, "Debug", :default => false
  opt :raw, "Dump raw JSON, not pretty-printed", :default => false
  opt :nocache, "Suppress caching", :default => false
  opt :expiration, "Cache expiration in seconds", :default => 7 * 24 * 60 * 60
  opt :apikey, "Infogroup API key", :default => ENV['INFOGROUP_APIKEY']
  opt :nossl, "Do NOT use SSL", :default => false
  opt :username, "Application username for API authentication (#{ENV['USER']})", :type => :string, :default => ENV['USER']
  opt :password, "Application password for API authentication", :type => :string
end

consumer_id = ARGV.shift

unless opts[:nocache]
  begin
    @cache = Redis.new.connect
  rescue
    $stderr.puts "Redis is not running; run with --nocache"
    @cache = nil
  end
end

api = InfogroupSearchAPI.new(opts.merge(:cache => @cache))

start_ts = Time.now
result = api.consumer_lookup(consumer_id)
elapsed = Time.now - start_ts

ap result
$stderr.puts "Elapsed: #{elapsed}" if opts[:debug]
