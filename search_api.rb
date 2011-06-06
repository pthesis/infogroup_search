module SearchApi
  include ActiveSupport::Benchmarkable
  ApiHost = {
    :development => "apiservicesdev.infogroup.com",
    :test => "apiservicestest.infogroup.com",
    :production => "apiservices.infogroup.com"
  }
  DefaultApiKey = ENV["INFOGROUP_API"]

  delegate :logger, :to => Rails

  def get(path, query = {})
    request = construct_request(path, query)
    log(request) do
      build_http.request(request)
    end
  end

  def construct_request(path, hsh = {})
    hsh = hsh.merge(default_params)
    hsh.merge!(default_consumer_params) if consumer?(path)
    full_path = "/searchapi-noesb/#{path}"
    request = Net::HTTP::Get.new("#{full_path}?#{hsh.to_query}")
    request["Accept"] = "application/json"
    request
  end

  def consumer?(path)
    path.starts_with?("usconsumer")
  end

  private

  def log(request)
    headers = request.each_header.map {|k,v| "#{k}=>#{v}" }
    logger.info { "Requesting with headers: #{headers}" }
    benchmark "Retreived #{request.path}" do
      yield
    end
  end
  
  def api_host(env)
    ApiHost.fetch(env)
  end

  def build_http
    http = Net::HTTP.new(api_host(:test))
    log_stream = File.open(Rails.root.join("log/http.log"), "a")
    http.set_debug_output(log_stream) if (Rails.env.development? || Rails.env.test?)
    http
  end

  def default_params
    { apiKey: DefaultApiKey }
  end

  def default_consumer_params
    { TargetReadyMinimumLevel: 9, LifestyleMinimumLevel: 7, ReturnAllResidents: true }
  end
end
