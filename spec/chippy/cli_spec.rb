require "spec_helper"
require "stringio"

RSpec.describe Chippy::CLI do
  let(:default_options) do
    described_class.default_options
  end

  it "uses default options when no arguments are provided" do
    allow(Chippy).to receive(:start)

    described_class.run([])

    expect(Chippy).to have_received(:start).with(default_options)
  end

  it "uses custom options when arguments are provided" do
    custom_options = {
      port: 12345,
      hostname: "custom-hostname",
      concurrency: 5,
      redis_url: "redis://custom-redis-url",
      redis_list: "custom_redis_list"
    }

    allow(Chippy).to receive(:start)

    args = [
      "--port", custom_options[:port].to_s,
      "--hostname", custom_options[:hostname],
      "--concurrency", custom_options[:concurrency].to_s,
      "--redis-url", custom_options[:redis_url],
      "--redis-list", custom_options[:redis_list]
    ]

    described_class.run(args)

    expect(Chippy).to have_received(:start).with(custom_options)
  end

  # rubocop:disable RSpec/ExpectOutput
  it "shows help message on invalid options" do
    allow(Chippy).to receive(:start)

    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new

    begin
      expect {
        described_class.run(["--invalid-option"])
      }.to raise_error(SystemExit)
    rescue SystemExit
      expect($stdout.string).to match(/Usage: start \[options\]/)
      expect(Chippy).not_to have_received(:start)
    ensure
      $stdout = original_stdout
      $stderr = original_stderr
    end
  end
  # rubocop:enable RSpec/ExpectOutput
end
