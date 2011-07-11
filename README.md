title: README

Ruby gem for interface to Infogroup Search API.

    api = InfogroupSearchAPI.new(config_options)
    api.consumer_count(params)
    api.consumer_search(params)
    api.business_count(params)
    api.business_search(params)
    api.consumer_lookup(id)
    api.business_lookup(id)

# Command-line invocation

    bin/dosearch.rb [options] [search criteria]
    bin/consumer.rb [options] id
    bin/business.rb [options] id

## Options

    opt :env, "Environment", :type => :string, :default => "test"
    opt :counts, "Counts", :default => false
    opt :business, "Use Business database", :default => false
    opt :pagesize, "Results page size", :type => :int, :default => 10
    opt :format, "Results in XML", :default => "json"
    opt :households, "Households", :default => false
    opt :debug, "Debug", :default => false
    opt :raw, "Dump raw JSON, not pretty-printed", :default => false
    opt :noesb, "Bypass ESB", :default => false
    opt :metadata, "Metadata field", :type => :string
    opt :nocache, "Suppress caching", :default => false
    opt :expiration, "Cache expiration in seconds", :default => 7 * 24 * 60 * 60

## Search Criteria

name=value pairs.  The entire "name=value" string must be quoted if the value contains any spaces or commas, probably safest to quote it if there is any non-alphanumerics at all.

# Notes

If a :cache option is passed in, the API will use it (via memcached/dalli or redis, anything that supports get/set).

# TODO

Multi-search mode for `dosearch`.  If there is input on STDIN, use each line as a set of criteria to be merged with the command-line criteria.

Add a "tally" mode to the library that looks up the enumerated type values via a metadata query, runs multiple counts and consolidates the results.  Cache the consolidated result set.
