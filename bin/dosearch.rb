#!/usr/bin/env ruby

require "ap"
require "trollop"
require "redis"
load "#{File.dirname(__FILE__)}/../lib/infogroup_search.rb"


opts = Trollop::options do
  opt :env, "Environment", :type => :string, :default => "test"
  opt :counts, "Counts", :default => false
  opt :business, "Use Business database", :default => false
  opt :pagesize, "Results page size", :type => :int, :default => 10
  opt :format, "Results in XML", :default => "json"
  opt :individuals, "Retrieve all individuals records (no householding)", :default => false
  opt :debug, "Debug", :default => false
  opt :raw, "Dump raw JSON, not pretty-printed", :default => false
  opt :noesb, "Bypass ESB", :default => false
  opt :metadata, "Metadata field", :type => :string
  opt :nocache, "Suppress caching", :default => false
  opt :onlycache, "Only check for result in cache, do not go to main API", :default => false
  opt :expiration, "Cache expiration in seconds", :default => 7 * 24 * 60 * 60
  opt :ssl, "Connect with HTTPS", :default => false
  opt :apikey, "Infogroup API key, overrides APIKEY from environment", :type => :string, :default => ENV["INFOGROUP_APIKEY"]
end

params = ARGV.inject({}) do |h,arg|
  if arg.match(/^(.*)=(.*)/)
    k,v = $1, $2 #arg.split(/=/)
    h[k] = v
  end
  h
end

unless opts[:nocache]
  @cache = Redis.new
  # @cache = Dalli::Client.new('localhost:11211', :expires_in => opts[:expiration])
  # raise "Unable to connect to memcached, aborting" unless @cache
end

api = InfogroupSearchAPI.new(opts.merge(:cache => @cache))

start_ts = Time.now
result = if opts[:business]
  if opts[:counts]
    api.business_count(params, opts)
  else
    api.business_search(params, opts)
  end
else
  if opts[:counts]
    api.consumer_count(params, opts)
  else
    api.consumer_search(params, opts)
  end
end
elapsed = Time.now - start_ts

ap result
$stderr.puts "Elapsed: #{elapsed}" if opts[:debug]

# if STDIN.tty?
#   api.execute(http, base_uri, params, opts, headers)
# else
#   STDIN.each_line do |line|
#     $stderr.puts line if opts[:debug]
# 
#     lineparams = Shellwords.shellwords(line).inject({}) do |h,arg|
#       k,v = arg.split(/=/)
#       h[k] = v
#       h
#     end
# 
#     api.execute(http, base_uri, params.merge(lineparams), opts, headers)
#   end
# end
