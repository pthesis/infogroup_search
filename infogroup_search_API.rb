require "net/http"
require "addressable/uri"
require "json"
require "dalli"

class InfogroupSearchAPI
  attr_reader :config

  # config options:
  # env: dev, test, prod
  # noesb: true/false
  # format: xml or json; default is json
  # user_agent: overrides default
  # debug: logging on/off
  # apikey: overrides ENV["INFOGROUP_APIKEY"]
  # default_radius: override default search radius of 5 miles
  # default_pagesize: override default page size of 10 records
  # raw: returns raw HTTP response instead of parsing XML or JSON
  def initialize(config = {})
    @config = {}
    @base_url = base_url
    @config[:apikey] ||= ENV["INFOGROUP_APIKEY"]
    @config[:default_radius] = 5
    @config[:default_pagesize] = 10
    @config[:noesb] = config[:noesb]
    @config[:debug] = config[:debug]
    @config[:raw] = config[:raw]
    @config[:format] = config[:format]
    @config[:env] = config[:env]

    unless config[:nocache]
      @cache = Dalli::Client.new('localhost:11211')
      raise "Unable to connect to memcached, aborting" unless @cache
    end

    @headers = {
     "Content-Type" => "application/json; charset=utf-8",
     "Accept" => config[:format] == "xml" ? "application/xml" : "application/json",
     "User-Agent" => config[:user_agent] || "infogroup_search_API.rb"
    }

    raise "Missing Infogroup API key" unless @config[:apikey]
  end

  def full_params(inputs, opts)
    params = inputs.dup

    if params["zip"]
      params.merge!("radiuspostalcode" => params["zip"], "radiusmiles" => params["miles"] || config[:default_radius])
      params.delete("zip")
      params.delete("miles")
    end

    params["apikey"] = config[:apikey]
    params["pagesize"] = opts[:pagesize] || config[:default_pagesize] unless opts[:counts]
    params["ReturnAllResidents"] = "true" unless opts[:households]
    params["LifestyleMinimumLevel"] = "7"
    params["TargetReadyMinimumLevel"] = "9"

    params
  end

  def consumer_count(criteria, options)
    if @cache
      result = @cache.get(criteria)
      if result
        $stderr.puts "USING CACHE!"
        return result
      end
    end
    result = execute(build_url("usconsumer", true), full_params(criteria, options), :counts => true)
    if @cache
      @cache.set(criteria, result)
      $stderr.puts "CACHING!"
    end
    result
  end
  def consumer_search(criteria, options)
    execute(build_url("usconsumer", false), full_params(criteria, options), :counts => false)
  end
  def business_count(criteria, options)
    execute(build_url("usbusiness", true), full_params(criteria, options), :counts => true)
  end
  def business_search(criteria, options)
    execute(build_url("usbusiness", false), full_params(criteria, options), :counts => false)
  end

  private

  def http
    @http ||= Net::HTTP.new(base_url.host, base_url.port)
  end

  def base_url
    env = case config[:env]
    when "prod"
      ""
    when "dev"
      "dev"
    else
      "test"
    end

    Addressable::URI.parse("http://apiservices#{env}.infogroup.com/searchapi#{config[:noesb] ? '-noesb' : ''}")
  end

  def build_url(db, counts)
    url = base_url.dup
    url.path = [
      url.path,
      db,
      counts ? "counts" : ""
    ].join("/")
    url
  end

  def execute(uri, params, extra_opts)
    # must stringify all values for URI query string assembly
    uri.query_values = params.inject({}) {|h,(k,v)| h[k] = v.to_s;h}

    $stderr.puts uri if config[:debug]

    resp = http.get2(uri.omit(:scheme, :host).to_s, @headers)
    if (resp.code != "200")
      $stderr.puts "HTTP response code: #{resp.code}"
      $stderr.puts resp.body
      exit 1
    else
      if (config[:format] == "xml") || config[:raw]
        resp.body
      else
        json = resp.body
        if extra_opts[:counts]
          JSON.load(json)["MatchCount"] || 0
        else
          JSON.load(json)
        end
      end
    end
  end
end
