#!/usr/bin/env ruby

require "net/http"
require "ap"
require "addressable/uri"
require "json"
require "trollop"

opts = Trollop::options do
  opt :env, "Environment", :type => :string, :default => "dev"
  opt :xml, "Results in XML"
end
opts[:env] = "" if opts[:env] == "prod"

id = ARGV.shift or exit 1

base_url = "http://apiservices#{opts[:env]}.infogroup.com/searchapi/usconsumer"
apikey = "11445"

headers = {
  "Content-Type" => "application/json; charset=utf-8",
  "Accept" => opts[:xml] ? "application/xml" : "application/json",
  "User-Agent" => "fuelprosper API test"
}

params = {}
params["apikey"] = apikey

uri = Addressable::URI.parse([
  base_url,
  id
  ].join("/")
  )
uri.query_values = params

puts uri

http = Net::HTTP.new(uri.host, uri.port)
resp = http.get2(uri.omit(:scheme, :host).to_s, headers)
ap resp
if opts[:xml]
  puts resp.body
else
  json = resp.body
  ap JSON.load(json)
end
