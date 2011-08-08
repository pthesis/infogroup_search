require "net/http"
require "net/https"
require "json"
require "digest"

class InfogroupSearchAPI
  VERSION = "0.1"

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
  # cache: use this for results caching
  # onlycache: look for results in the cache, but don't go to the API on a cache miss
  # ssl: if true, use https
  # user_agent: override default user-agent in API request
  def initialize(config = {})
    @config = {}
    @config[:apikey] = config[:apikey] #||= ENV["INFOGROUP_APIKEY"]
    @config[:default_radius] = 5
    @config[:default_pagesize] = 10
    @config[:noesb] = config[:noesb]
    @config[:debug] = config[:debug]
    @config[:raw] = config[:raw]
    @config[:format] = config[:format] || "json"
    @config[:env] = config[:env] || "prod"
    @config[:onlycache] = config[:onlycache]
    @cache = config[:cache]
    @config[:scheme] = config[:ssl] ? "https" : "http"

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
      params["ReturnAllResidents"] = opts[:individuals] ? "true" : "false"
      params["LifestyleMinimumLevel"] = "7"
      params["TargetReadyMinimumLevel"] = "9"
      params["LifestyleOperator"] = "OR"
    end

    params
  end

  private

  def http
    @http ||= establish_http
  end

  def establish_http
    url = URI.parse(domain)
    http = Net::HTTP.new(url.host, url.port)
    if config[:scheme] == "https"
      http.use_ssl = true 
      # http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      # 
      # http.ca_path = '/etc/ssl/certs' if File.exists?('/etc/ssl/certs') # Ubuntu
      # http.ca_file = '/opt/local/share/curl/curl-ca-bundle.crt' if File.exists?('/opt/local/share/curl/curl-ca-bundle.crt') # Mac OS X
    end
    # http.set_debug_output("/tmp/http.log")
    http
  end

  def domain
    env = case config[:env]
    when "prod"
      ""
    when "dev"
      "dev"
    else
      "test"
    end

    "#{config[:scheme]}://apiservices#{env}.infogroup.com"
  end

  def build_url(options)
    root = "/searchapi#{config[:noesb] ? '-noesb' : ''}"
    path = if options[:metadata]
      [
        # url.path,
        root,
        "metadata",
        options[:db],
        options[:metadata]
      ].join("/")
    elsif options[:id]
      [
#        url.path,
        root,
        options[:db],
        options[:id]
      ].join("/")
    else
      [
        # url.path,
        root,
        options[:db],
        options[:counts] ? "counts" : ""
      ].join("/")
    end
    # Net::HTTP::Get.new(path)
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

    path = build_url(options)
    # must stringify all values for URI query string assembly
    query_hash = params.inject({}) {|h,(k,v)| h[k] = v.to_s;h}
    query_string = query_hash.map{|k,v| "#{URI.encode(k)}=#{URI.encode(v)}"}.join("&")
    request = Net::HTTP::Get.new("#{path}?#{query_string}")
    
    # uri.query_values = params.inject({}) {|h,(k,v)| h[k] = v.to_s;h}

    if config[:debug]
      $stderr.puts "#{config[:scheme]}://#{http.address}#{request.path}"
    end

    # resp = http.get2(uri.omit(:scheme, :host).to_s, @headers)
    @headers.each {|k,v| request[k] = v}
    resp = http.request(request)
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
