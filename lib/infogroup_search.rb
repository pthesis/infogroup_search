require "net/http"
require "net/https"
require "json"
require "yaml"
require "digest"

class InfogroupSearchAPI
  VERSION = "0.2"
  APIKEY_LIFETIME = 72 * 60 * 60 # supposed to expire after 24 hours, setting this higher to allow 401s to happen

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
  # nossl: if true, use http; default is https
  # user_agent: override default user-agent in API request
  def initialize(config = {})
    @config = {}
    @config[:env] = config[:env] || "prod"
    # @config[:apikey] = config[:apikey] || cached_apikey
    @config[:default_radius] = 5
    @config[:default_pagesize] = 10
    @config[:noesb] = config[:noesb]
    @config[:debug] = config[:debug]
    @config[:raw] = config[:raw]
    @config[:format] = config[:format] || "json"
    @config[:onlycache] = config[:onlycache]
    @cache = config[:cache]
    @config[:scheme] = config[:nossl] ? "http" : "https"
    @config[:tally] = config[:tally]
    @config[:ids] = config[:ids]

    @headers = {
     "Content-Type" => "application/json; charset=utf-8",
     "Accept" => config[:format] == "xml" ? "application/xml" : "application/json",
     "User-Agent" => config[:user_agent] || "github.com/jmay/infogroup_search"
    }

    @config[:username] = config[:username]
    @config[:password] = config[:password]
    authenticate!(:app => $0.split("/").last, :username => config[:username], :password => config[:password])
    self
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
  def authentication(options)
    execute({}, {
      :db => "authenticate",
      :id => "#{options[:username]}/#{options[:password]}/#{options[:app]}",
      :suppress_params => true})
  end

  def authenticate!(opts)
    config_filename = "#{ENV['HOME']}/.infogroup/config.#{config[:env]}.yaml"
    api_config = YAML.load_file(config_filename) rescue {}
    begin
      apikey_age = Time.now - Time.parse(api_config[:apikey_timestamp])
      # force key renewal
      raise "expired" if apikey_age > APIKEY_LIFETIME || opts[:force]
      $stderr.puts "Using cached API key..."
      @config[:apikey] = api_config[:apikey]
    rescue
      # generate new API key
      $stderr.puts "Generating new API key..."
      auth_response = authentication(opts) # opts should contain username, password, app
      api_config[:apikey] = auth_response["ApiKey"]
      api_config[:apikey_timestamp] = Time.now.to_s
      File.open(config_filename, "w") {|f| f << api_config.to_yaml}
      @config[:apikey] = api_config[:apikey]
    end
  end

  def full_params(inputs, opts)
    params = inputs.dup

    if params["zip"]
      params.merge!("radiuspostalcode" => params["zip"], "radiusmiles" => params["miles"] || config[:default_radius])
      params.delete("zip")
      params.delete("miles")
    end

    params["apikey"] = config[:apikey]

    # only need pagesize when retrieving lists of results, not for counts or single-record lookups
    params["pagesize"] = opts[:pagesize] || config[:default_pagesize] unless opts[:counts] || opts[:metadata] || opts[:id]

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
    elsif options[:tally]
      [
        root,
        options[:db],
        "tally"
      ].join("/")
    elsif options[:ids]
      [
        root,
        options[:db],
        "recordids"
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
    if options[:tally]
      criteria["tally#{options[:tally]}"] = true
    end

    if options[:suppress_params]
      params = nil
    else
      params = full_params(criteria, options)
    end
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
    if params
      query_hash = params.inject({}) {|h,(k,v)| h[k] = v.to_s;h}
      query_string = query_hash.map{|k,v| "#{URI.encode(k)}=#{URI.encode(v)}"}.join("&")
      full_path = "#{path}?#{query_string}"
    else
      full_path = path
    end
    request = Net::HTTP::Get.new(full_path)
    
    # uri.query_values = params.inject({}) {|h,(k,v)| h[k] = v.to_s;h}

    if config[:debug]
      $stderr.puts "#{config[:scheme]}://#{http.address}#{request.path}"
    end

    # resp = http.get2(uri.omit(:scheme, :host).to_s, @headers)
    @headers.each {|k,v| request[k] = v}
    resp = http.request(request)
    case resp.code
    when "401"
      $stderr.puts "API key expired, renewing"
      if !options[:authenticated] && authenticate!(:app => $0.split("/").last, :username => config[:username], :password => config[:password], :force => true)
        execute(criteria, options.merge(:authenticated => true))
      else
        $stderr.puts "Authentication failed, giving up"
        nil
      end
    when "200"
      if (config[:format] == "xml") || config[:raw]
        return resp.body
      end
      # if config[:debug]
      #   resp.each_header do |h,v|
      #     $stderr.puts ">>> #{h}: #{v}"
      #   end
      # end
      json = resp.body
      if options[:counts]
        result = JSON.load(json)["MatchCount"] || 0
      elsif options[:tally]
        tallies = JSON.load(json)["Data"]
        keyname = tallies.first.keys.select {|k| k !~ /RecordCount/}.first
        result = tallies.inject({}) do |hash,tally|
          hash[tally[keyname]] = tally["RecordCount"]
          hash
        end
      else
        result = JSON.load(json)
      end

      if @cache
        @cache.set(key, result)
        $stderr.puts "CACHING: #{keyparams}" if config[:debug]
      end
      result
    else
      $stderr.puts "HTTP error response code: #{resp.code}"
      $stderr.puts resp.body
      nil
    end
  end

  def cached_apikey
    File.read("#{ENV['HOME']}/.infogroup/apikey.#{config[:env]}").strip
  end
end
