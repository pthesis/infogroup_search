#!/usr/bin/env ruby

require "net/http"
require "ap"
require "addressable/uri"
require "json"
require "trollop"


class SearchAPI
  def execute(http, base_uri, params, opts, headers)
    uri = base_uri.dup
    uri.query_values = params

    $stderr.puts uri if opts[:debug]

    resp = http.get2(uri.omit(:scheme, :host).to_s, headers)
    if (resp.code != "200")
      $stderr.puts "HTTP response code: #{resp.code}"
      $stderr.puts resp.body
      exit 1
    else
      if opts[:xml] || opts[:raw]
        puts resp.body
      else
        json = resp.body
        if opts[:counts]
          puts JSON.load(json)["MatchCount"] || 0
        else
          ap JSON.load(json)
        end
      end
    end
  end
end


opts = Trollop::options do
  opt :env, "Environment", :type => :string, :default => "test"
  opt :counts, "Counts", :default => false
  opt :business, "Use Business database", :default => false
  opt :pagesize, "Results page size", :type => :int, :default => 10
  opt :xml, "Results in XML", :default => false
  opt :households, "Households", :default => false
  opt :debug, "Debug", :default => false
  opt :raw, "Dump raw JSON, not pretty-printed", :default => false
  opt :noesb, "Bypass ESB", :default => false
end

opts[:env] = "" if opts[:env] == "prod"

base_url = "http://apiservices#{opts[:env]}.infogroup.com/searchapi#{opts[:noesb] ? '-noesb' : ''}"
apikey = "11445"

headers = {
 "Content-Type" => "application/json; charset=utf-8",
 "Accept" => opts[:xml] ? "application/xml" : "application/json",
 "User-Agent" => "fuelprosper API test"
  # "Accept" => "*/*",
  # "User-Agent" => "curl/7.19.7 (universal-apple-darwin10.0) libcurl/7.19.7 OpenSSL/0.9.8l zlib/1.2.3"
}

params = ARGV.inject({}) do |h,arg|
  k,v = arg.split(/=/)
  h[k] = v
  h
end

if params["zip"]
  params.merge!("radiuspostalcode" => params["zip"], "radiusmiles" => params["miles"] || "5")
  params.delete("zip")
  params.delete("miles")
end

params["apikey"] = apikey
params["pagesize"] = opts[:pagesize].to_s unless opts[:counts]
params["LifestyleMinimumLevel"] = "7"
params["TargetReadyMinimumLevel"] = "9"
params["ReturnAllResidents"] = "true" unless opts[:households]

base_uri = Addressable::URI.parse([
  base_url,
  opts[:business] ? "usbusiness" : "usconsumer",
  opts[:counts] ? "counts" : ""
  ].join("/")
  )

http = Net::HTTP.new(base_uri.host, base_uri.port)

api = SearchAPI.new

if STDIN.tty?
  api.execute(http, base_uri, params, opts, headers)
else
  STDIN.each_line do |line|
    $stderr.puts line if opts[:debug]

    lineparams = Shellwords.shellwords(line).inject({}) do |h,arg|
      k,v = arg.split(/=/)
      h[k] = v
      h
    end

    api.execute(http, base_uri, params.merge(lineparams), opts, headers)
  end
end
