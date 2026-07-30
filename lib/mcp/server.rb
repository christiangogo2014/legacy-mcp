module Mcp
  class Server
    def initialize(name:, version:, user:, resources: [], tools: [])
      @name = name
      @version = version
      @user = user
      @resources = resources
      @tools = tools
      @initialized = false
    end

    def handle_request(request_body)
      request = JSON.parse(request_body)

      case request['method']
      when 'initialize'
        handle_initialize(request)
      when 'ping'
        handle_ping(request)
      when 'resources/list'
        handle_resources_list(request)
      when 'resources/read'
        handle_resources_read(request)
      when 'tools/list'
        handle_tools_list(request)
      when 'tools/call'
        handle_tools_call(request)
      else
        error_response(request['id'], -32601, 'Method not found')
      end
    rescue JSON::ParserError
      error_response(nil, -32700, 'Parse error')
    rescue => e
      error_response(request&.dig('id'), -32603, "Internal error: #{e.message}")
    end

    private

    def handle_initialize(request)
      @initialized = true
      success_response(request['id'], {
        protocolVersion: '2024-11-05',
        serverInfo: {
          name: @name,
          version: @version
        },
        capabilities: {
          tools: {},
          resources: { subscribe: false, listChanged: false }
        }
      })
    end

    def handle_ping(request)
      success_response(request['id'], {})
    end

    def handle_resources_list(request)
      resources_data = @resources.map do |resource_class|
        resource = resource_class.new
        {
          uri: resource.uri,
          name: resource.name,
          description: resource.description,
          mimeType: resource.mime_type
        }
      end

      success_response(request['id'], { resources: resources_data })
    end

    def handle_resources_read(request)
      uri = request.dig('params', 'uri')
      resource_class = @resources.find { |r| r.new.uri == uri }

      return error_response(request['id'], -32602, 'Resource not found') unless resource_class

      resource = resource_class.new
      contents = resource.read(request.dig('params', 'arguments') || {}, @user)

      success_response(request['id'], { contents: [contents] })
    end

    def handle_tools_list(request)
      tools_data = @tools.map do |tool_class|
        tool = tool_class.new
        {
          name: tool.name,
          description: tool.description,
          inputSchema: tool.input_schema
        }
      end

      success_response(request['id'], { tools: tools_data })
    end

    def handle_tools_call(request)
      tool_name = request.dig('params', 'name')
      arguments = request.dig('params', 'arguments') || {}

      tool_class = @tools.find { |t| t.new.name == tool_name }
      return error_response(request['id'], -32602, 'Tool not found') unless tool_class

      tool = tool_class.new
      result_text = tool.call(arguments, @user)

      success_response(request['id'], {
        content: [{ type: 'text', text: result_text }],
        isError: false
      })
    rescue => e
      success_response(request['id'], {
        content: [{ type: 'text', text: "Error: #{e.message}" }],
        isError: true
      })
    end

    def success_response(id, result)
      { jsonrpc: '2.0', id: id, result: result }.to_json
    end

    def error_response(id, code, message)
      { jsonrpc: '2.0', id: id, error: { code: code, message: message } }.to_json
    end
  end
end
