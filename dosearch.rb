#!/usr/bin/env ruby

require "ap"
require "trollop"
require "./infogroup_search_API"


opts = Trollop::options do
  opt :env, "Environment", :type => :string, :default => "test"
  opt :counts, "Counts", :default => false
  opt :business, "Use Business database", :default => false
  opt :pagesize, "Results page size", :type => :int, :default => 10
  opt :format, "Results in XML", :default => "json"
  opt :households, "Households", :default => false
  opt :debug, "Debug", :default => false
  opt :raw, "Dump raw JSON, not pretty-printed", :default => false
  opt :noesb, "Bypass ESB", :default => false
end

params = ARGV.inject({}) do |h,arg|
  k,v = arg.split(/=/)
  h[k] = v
  h
end

api = InfogroupSearchAPI.new(opts)

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

ap result

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
