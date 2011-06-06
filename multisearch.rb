#!/usr/bin/env ruby

require "net/http"
require "ap"
require "addressable/uri"
require "json"
require "trollop"
require "shellwords"

opts = Trollop::options do
  opt :env, "Environment", :type => :string, :default => "dev"
  opt :counts, "Counts"
  opt :business, "Use Business database"
  opt :pagesize, "Results page size", :type => :int, :default => 10
  opt :xml, "Results in XML"
  opt :households, "Households", :default => false
  opt :debug, "Debug", :default => false
end

opts[:env] = "" if opts[:env] == "prod"

base_url = "http://apiservices#{opts[:env]}.infogroup.com/searchapi"
apikey = "11445"

headers = {
  "Content-Type" => "application/json; charset=utf-8",
  "Accept" => opts[:xml] ? "application/xml" : "application/json",
  "User-Agent" => "fuelprosper API test"
}

base_uri = Addressable::URI.parse([
  base_url,
  opts[:business] ? "usbusiness" : "usconsumer",
  opts[:counts] ? "counts" : ""
  ].join("/")
  )

http = Net::HTTP.new(base_uri.host, base_uri.port)

STDIN.each_line do |line|
  puts line
  params = Shellwords.shellwords(line).inject({}) do |h,arg|
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

  uri = base_uri.dup
  uri.query_values = params

  $stderr.puts uri if opts[:debug]

  resp = http.get2(uri.omit(:scheme, :host).to_s, headers)
  if (resp.code != "200")
    $stderr.ap resp
  else
    if opts[:xml]
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
