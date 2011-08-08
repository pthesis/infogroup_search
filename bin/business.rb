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
end

business_id = ARGV.shift

unless opts[:nocache]
  @cache = Redis.new
  # @cache = Dalli::Client.new('localhost:11211', :expires_in => opts[:expiration])
  # raise "Unable to connect to memcached, aborting" unless @cache
end

api = InfogroupSearchAPI.new(opts.merge(:cache => @cache))

start_ts = Time.now
result = api.business_lookup(business_id)
elapsed = Time.now - start_ts

ap result
$stderr.puts "Elapsed: #{elapsed}" if opts[:debug]
