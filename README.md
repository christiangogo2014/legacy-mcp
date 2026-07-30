# legacy-mcp

**MCP (Model Context Protocol) server framework for legacy Ruby/Rails apps (Ruby >= 2.6) that cannot run the official `mcp` gem.**

> **⚠️ WORK IN PROGRESS** — This gem is under active development and not yet published to RubyGems.org. The API may change before a 1.0 release.

## Why?

The official [`mcp`](https://rubygems.org/gems/mcp) gem requires newer Ruby versions, Many Rails projects were written years ago and run on Ruby lower versions. leaving these legacy apps unable to expose their data to AI assistants via the Model Context Protocol.

`legacy-mcp` fills that gap: a lightweight, pure-Ruby MCP server framework with **zero Rails dependency** that works on Ruby >= 2.6. It speaks the [MCP JSON-RPC protocol](https://spec.modelcontextprotocol.io/) (protocol version `2024-11-05`) and provides base classes for defining resources and tools.

## Requirements

- Ruby >= 2.6
- No Rails dependency — works with any Rack-compatible framework (Sinatra, Grape, plain Rack, etc.)

> **Note:** Do not combine this gem with the official `mcp` gem in the same project. Both use the `Mcp::` namespace and will conflict.

## Installation

Add to your Gemfile:

```ruby
gem 'legacy-mcp', github: 'christiangogo2014/legacy-mcp'
```

Or from a local path during development:

```ruby
gem 'legacy-mcp', path: '../legacy-mcp'
```

## Quick Start

### 1. Define a resource

```ruby
require 'legacy-mcp'

class UsersResource < Mcp::BaseResource
  def uri
    'myapp://users'
  end

  def name
    'Users List'
  end

  def description
    'Returns all users in the system'
  end

  def fetch_data(arguments, user)
    { users: User.all.as_json }
  end
end
```

### 2. Define a tool

```ruby
class CreateUserTool < Mcp::BaseTool
  def name
    'create_user'
  end

  def description
    'Creates a new user account'
  end

  def input_schema
    {
      type: 'object',
      properties: {
        email: { type: 'string', description: 'User email address' }
      },
      required: ['email'],
      additionalProperties: false
    }
  end

  def call(arguments, user)
    record = User.create!(email: arguments['email'])
    { id: record.id, email: record.email }.to_json
  end
end
```

### 3. Register resources and tools in an initializer

Keeping the server configuration in an initializer means your controller stays thin and the resource/tool list is defined in one place.

```ruby
# config/initializers/mcp.rb
require 'legacy-mcp'

Rails.application.config.tap do |config|
  config.mcp_server_name    = 'my_app_mcp'
  config.mcp_server_version = '1.0.0'
  config.mcp_resources = [UsersResource]
  config.mcp_tools     = [CreateUserTool]
end
```

### 4. Wire the controller

The controller handles auth, reads the config from the initializer, and delegates to `Mcp::Server`.

```ruby
# config/routes.rb
post '/mcp', to: 'mcp#handle'

# app/controllers/mcp_controller.rb
class McpController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_api_token
  before_action :setup_mcp_server

  def handle
    response_json = @mcp_server.handle_request(request.body.read)
    render json: JSON.parse(response_json), status: :ok
  rescue => e
    Rails.logger.error "MCP Error: #{e.message}"
    render json: {
      jsonrpc: '2.0', id: nil,
      error: { code: -32603, message: "Internal error: #{e.message}" }
    }, status: :internal_server_error
  end

  private

  # Example: Bearer token auth — adapt to your app's auth strategy
  def authenticate_api_token
    auth_header = request.headers['Authorization']
    return render_auth_error('Missing Authorization header') if auth_header.blank?

    token = auth_header.sub(/^Bearer /, '')
    @current_user = User.find_by(api_token: token)
    render_auth_error('Invalid API token') if @current_user.nil?
  end

  def render_auth_error(message)
    render json: {
      jsonrpc: '2.0',
      id: nil,
      error: { code: -32001, message: "Unauthorized: #{message}" }
    }, status: :unauthorized
  end

  def setup_mcp_server
    config = Rails.application.config
    @mcp_server = Mcp::Server.new(
      name: config.mcp_server_name,
      version: config.mcp_server_version,
      user: @current_user,
      resources: config.mcp_resources,
      tools: config.mcp_tools
    )
  end
end
```

> **Auth is app-specific.** The gem does not impose an auth strategy. The example above uses a Bearer token lookup, but you can use Devise, cookies, API keys, or any mechanism — just set `@current_user` (or whatever object your resources/tools expect) before calling `setup_mcp_server`.

## Protocol Support

| Method | Status |
|---|---|
| `initialize` | ✅ |
| `ping` | ✅ |
| `resources/list` | ✅ |
| `resources/read` | ✅ |
| `tools/list` | ✅ |
| `tools/call` | ✅ |
| `resources/subscribe` | ❌ |
| `notifications/*` | ❌ |

## License

MIT — see [LICENSE](LICENSE).
