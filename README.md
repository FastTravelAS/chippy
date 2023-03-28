# Chippy
![Chippy mascot](chippy.png)
<small>Mascot created by Midjourney</small>

Chippy is a standalone Ruby service designed to simplify the process of communicating with chip readers. It handles establishing connections, managing the handshake process, and efficiently processing incoming messages from multiple devices.

## Features

- Easy-to-use API for handling chip reader connections and messages.
- Multi-threaded server architecture for efficient handling of multiple connections.
- Handshake protocol implementation for seamless device communication.
- Error handling and logging to ensure reliable operation.

## Prerequisites

- Docker
- Ruby
- Redis

## Getting Started

1. Clone the Chippy repository:

```bash
git clone https://github.com/rubynor/chippy.git
```

2. Change into the Chippy directory:

```bash
cd chippy
```

3. Install the required Ruby gems:

```bash
bin/setup 
```

4. Start the Chippy server:

```bash
bin/start
```

## CLI
Chippy provides a command-line interface (CLI) for starting the server and configuring various options. You can use the bin/start script to run the server.

Usage:
```bash
bin/start [options]
```

Options:
* -p, --port: Set the port to use (default: 44999)
* -h, --hostname: Set the hostname to use (default: 0.0.0.0)
* -c, --concurrency: Set the number of concurrent worker threads (default: 10)
* --redis-url: Set the Redis connection URL (default: redis://localhost:6379/0)
* --redis-list: Set the Redis list name for the message broker (default: chippy:readings)

## Message Broker using Redis
Chippy uses a message broker to handle communication between Chippy devices and the associated Rails application. The Chippy::Client::RedisConsumer class provided by the Chippy gem is responsible for listening to a Redis list and processing messages accordingly.

Chippy devices push messages to the Redis list, and the Rails application uses the Chippy gem to consume and process these messages. By utilizing a pub/sub pattern with a Redis list, Chippy can maintain a decoupled architecture, allowing the devices and Rails application to communicate efficiently and asynchronously.

To configure the Chippy gem in the Rails application, add an initializer:

```ruby
# config/initializers/chippy.rb
Rails.application.config.chippy.queue_name = 'chippy:readings'
Rails.application.config.chippy.enable = true
Rails.application.config.chippy.message_handler = lambda do |message|
  Rails.logger.debug "Custom handler: Received message #{message}"
end
```

