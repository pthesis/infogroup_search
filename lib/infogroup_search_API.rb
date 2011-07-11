require "net/http"
require "addressable/uri"
require "json"
require "dalli"
require "digest"

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
    @config[:onlycache] = config[:onlycache]
    @cache = config[:cache]

    @headers = {
     "Content-Type" => "application/json; charset=utf-8",
     "Accept" => config[:format] == "xml" ? "application/xml" : "application/json",
     "User-Agent" => config[:user_agent] || "infogroup_search_API.rb"
    }

    raise "Missing Infogroup API key" unless @config[:apikey]
  end

  def consumer_count(criteria, options)
    execute(criteria, options.merge(:db => "usconsumer", :counts => true))
  end
  def consumer_search(criteria, options)
    execute(criteria, options.merge(:db => "usconsumer"))
  end
  def business_count(criteria, options)
    execute(criteria, options.merge(:db => "usbusiness", :counts => true))
  end
  def business_search(criteria, options)
    execute(criteria, options.merge(:db => "usbusiness"))
  end
  def consumer_metadata(field)
    execute({}, {:db => "usconsumer", :metadata => field})
  end
  def business_metadata(field)
    execute({}, {:db => "usbusiness", :metadata => field})
  end
  def consumer_lookup(id)
    execute({}, {:db => "usconsumer", :id => id})
  end
  def business_lookup(id)
    execute({}, {:db => "usbusiness", :id => id})
  end

  def full_params(inputs, opts)
    params = inputs.dup

    if params["zip"]
      params.merge!("radiuspostalcode" => params["zip"], "radiusmiles" => params["miles"] || config[:default_radius])
      params.delete("zip")
      params.delete("miles")
    end

    params["apikey"] = config[:apikey]
    params["pagesize"] = opts[:pagesize] || config[:default_pagesize] unless opts[:counts] || opts[:metadata]
    if opts[:db] == "usconsumer" && !opts[:metadata]
      params["ReturnAllResidents"] = "true" unless opts[:households]
      params["LifestyleMinimumLevel"] = "7"
      params["TargetReadyMinimumLevel"] = "9"
    end

    params
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

  def build_url(options)
    url = base_url.dup
    if options[:metadata]
      url.path = [
        url.path,
        "metadata",
        options[:db],
        options[:metadata]
      ].join("/")
    elsif options[:id]
      url.path = [
        url.path,
        options[:db],
        options[:id]
      ].join("/")
    else
      url.path = [
        url.path,
        options[:db],
        options[:counts] ? "counts" : ""
      ].join("/")
    end
    url
  end

  def execute(criteria = {}, options = {})
    params = full_params(criteria, options)
    if @cache
      keyparams = params.select {|k,v| k != "apikey"}.merge({:db => options[:db], :format => options[:format]})
      key = Digest::SHA2.hexdigest(keyparams.to_s)
      result = @cache.get(key)
      if result
        $stderr.puts "FOUND IN CACHE: #{keyparams}" if config[:debug]
        return result
      end
    end

    return if options[:onlycache]

    uri = build_url(options)
    # must stringify all values for URI query string assembly
    uri.query_values = params.inject({}) {|h,(k,v)| h[k] = v.to_s;h}

    $stderr.puts uri if config[:debug]

    resp = http.get2(uri.omit(:scheme, :host).to_s, @headers)
    result = if (resp.code != "200")
      $stderr.puts "HTTP response code: #{resp.code}"
      $stderr.puts resp.body
      exit 1
    else
      if (config[:format] == "xml") || config[:raw]
        resp.body
      else
        json = resp.body
        if options[:counts]
          JSON.load(json)["MatchCount"] || 0
        else
          JSON.load(json)
        end
      end
    end

    if @cache
      @cache.set(key, result)
      $stderr.puts "CACHING: #{keyparams}" if config[:debug]
    end
    result
  end
end
