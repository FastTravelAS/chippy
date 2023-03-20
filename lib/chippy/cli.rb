require "optparse"

module Chippy
  class CLI
    DEFAULT_PORT = 44999
    DEFAULT_CONCURRENCY = 10
    DEFAULT_HOSTNAME = "0.0.0.0"
    DEFAULT_REDIS_URL = "redis://localhost:6379"
    DEFAULT_REDIS_LIST = "chippy:readings"

    def self.default_options
      {
        port: (ENV.fetch("CHIPPY_PORT", DEFAULT_PORT)).to_i,
        hostname: (ENV.fetch("CHIPPY_HOSTNAME", DEFAULT_HOSTNAME)).to_s,
        concurrency: (ENV.fetch("CHIPPY_CONCURRENCY", DEFAULT_CONCURRENCY)).to_i,
        redis_url: (ENV.fetch("CHIPPY_REDIS_URL", DEFAULT_REDIS_URL)).to_s,
        redis_list: (ENV.fetch("CHIPPY_REDIS_LIST", DEFAULT_REDIS_LIST)).to_s
      }
    end

    def self.parse_options(args)
      options = {}

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: start [options]"
        opts.separator ""
        opts.separator "Default options:"
        opts.separator "  Port: #{DEFAULT_PORT}"
        opts.separator "  Hostname: #{DEFAULT_HOSTNAME}"
        opts.separator "  Concurrency: #{DEFAULT_CONCURRENCY}"
        opts.separator "  Redis URL: #{DEFAULT_REDIS_URL}"
        opts.separator "  Redis list name: #{DEFAULT_REDIS_LIST}"
        opts.separator ""

        opts.on("-pPORT", "--port=PORT", Integer, "Port to use (default: #{DEFAULT_PORT})") do |port|
          options[:port] = port
        end

        opts.on("-hHOSTNAME", "--hostname=HOSTNAME", String, "Hostname to use (default: #{DEFAULT_HOSTNAME})") do |hostname|
          options[:hostname] = hostname
        end

        opts.on("-cCONCURRENCY", "--concurrency=CONCURRENCY", Integer, "Concurrency (default: #{DEFAULT_CONCURRENCY})") do |concurrency|
          options[:concurrency] = concurrency
        end

        opts.on("--redis-url STRING", String, "Redis connection string (default: #{DEFAULT_REDIS_URL})") do |redis_url|
          options[:redis_url] = redis_url
        end

        opts.on("--redis-list STRING", String, "Redis key name (default: #{DEFAULT_REDIS_LIST})") do |redis_list|
          options[:redis_list] = redis_list
        end
      end

      begin
        parser.parse!(args)
      rescue OptionParser::InvalidOption, OptionParser::MissingArgument
        puts parser
        exit
      end

      options
    end

    def self.run(args)
      options = default_options

      parsed_options = parse_options(args)
      options.merge!(parsed_options)

      Chippy.start(options)
    end
  end
end
