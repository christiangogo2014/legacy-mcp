# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Server do
  let(:user) { double('User') }
  let(:server) do
    described_class.new(
      name: 'test_server',
      version: '1.0.0',
      user: user,
      resources: [DummyResource],
      tools: [DummyTool]
    )
  end

  before(:all) do
    # Define dummy classes for testing
    Object.const_set(:DummyResource, Class.new(Mcp::BaseResource) do
      def uri; 'test://resource'; end
      def name; 'Test Resource'; end
      def description; 'A test resource'; end
      def fetch_data(arguments, user)
        { data: 'hello', user: user&.class&.name, args: arguments }
      end
    end)

    Object.const_set(:DummyTool, Class.new(Mcp::BaseTool) do
      def name; 'test_tool'; end
      def description; 'A test tool'; end
      def input_schema
        { type: 'object', properties: { x: { type: 'string' } } }
      end
      def call(arguments, user)
        { result: 'ok', input: arguments }.to_json
      end
    end)

    Object.const_set(:ErrorTool, Class.new(Mcp::BaseTool) do
      def name; 'error_tool'; end
      def description; 'Always raises'; end
      def input_schema; { type: 'object' }; end
      def call(arguments, user)
        raise StandardError, 'Tool exploded'
      end
    end)
  end

  after(:all) do
    Object.send(:remove_const, :DummyResource)
    Object.send(:remove_const, :DummyTool)
    Object.send(:remove_const, :ErrorTool)
  end

  def parse_response(body)
    JSON.parse(server.handle_request(body))
  end

  describe 'initialize' do
    it 'returns protocol version and server info' do
      result = parse_response('{"jsonrpc":"2.0","id":1,"method":"initialize"}')
      expect(result['result']['protocolVersion']).to eq('2024-11-05')
      expect(result['result']['serverInfo']['name']).to eq('test_server')
      expect(result['result']['serverInfo']['version']).to eq('1.0.0')
    end

    it 'announces tools and resources capabilities' do
      result = parse_response('{"jsonrpc":"2.0","id":1,"method":"initialize"}')
      expect(result['result']['capabilities']).to have_key('tools')
      expect(result['result']['capabilities']).to have_key('resources')
    end
  end

  describe 'ping' do
    it 'returns empty result' do
      result = parse_response('{"jsonrpc":"2.0","id":2,"method":"ping"}')
      expect(result['result']).to eq({})
    end
  end

  describe 'resources/list' do
    it 'returns all registered resources' do
      result = parse_response('{"jsonrpc":"2.0","id":3,"method":"resources/list"}')
      resources = result['result']['resources']
      expect(resources.length).to eq(1)
      expect(resources.first['uri']).to eq('test://resource')
      expect(resources.first['name']).to eq('Test Resource')
      expect(resources.first['mimeType']).to eq('application/json')
    end
  end

  describe 'resources/read' do
    it 'returns resource contents for a valid URI' do
      body = '{"jsonrpc":"2.0","id":4,"method":"resources/read","params":{"uri":"test://resource"}}'
      result = parse_response(body)
      contents = result['result']['contents']
      expect(contents).to be_an(Array)
      expect(contents.first['uri']).to eq('test://resource')
      expect(contents.first['mimeType']).to eq('application/json')

      text = JSON.parse(contents.first['text'])
      expect(text['data']).to eq('hello')
    end

    it 'passes arguments to the resource' do
      body = '{"jsonrpc":"2.0","id":5,"method":"resources/read","params":{"uri":"test://resource","arguments":{"foo":"bar"}}}'
      result = parse_response(body)
      text = JSON.parse(result['result']['contents'].first['text'])
      expect(text['args']).to eq('foo' => 'bar')
    end

    it 'returns error for unknown URI' do
      body = '{"jsonrpc":"2.0","id":6,"method":"resources/read","params":{"uri":"unknown://nothing"}}'
      result = parse_response(body)
      expect(result['error']['code']).to eq(-32602)
      expect(result['error']['message']).to include('Resource not found')
    end
  end

  describe 'tools/list' do
    it 'returns all registered tools with schemas' do
      result = parse_response('{"jsonrpc":"2.0","id":7,"method":"tools/list"}')
      tools = result['result']['tools']
      expect(tools.length).to eq(1)
      expect(tools.first['name']).to eq('test_tool')
      expect(tools.first['inputSchema']).to eq('type' => 'object', 'properties' => { 'x' => { 'type' => 'string' } })
    end
  end

  describe 'tools/call' do
    it 'returns tool result content' do
      body = '{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"test_tool","arguments":{"x":"y"}}}'
      result = parse_response(body)
      expect(result['result']['isError']).to be false
      content = JSON.parse(result['result']['content'].first['text'])
      expect(content['result']).to eq('ok')
      expect(content['input']).to eq('x' => 'y')
    end

    it 'returns error for unknown tool' do
      body = '{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"nonexistent","arguments":{}}}'
      result = parse_response(body)
      expect(result['error']['code']).to eq(-32602)
      expect(result['error']['message']).to include('Tool not found')
    end

    it 'captures tool exceptions as isError: true' do
      server_with_error = Mcp::Server.new(
        name: 'test', version: '1.0.0', user: user,
        tools: [ErrorTool]
      )
      body = '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"error_tool","arguments":{}}}'
      result = JSON.parse(server_with_error.handle_request(body))
      expect(result['result']['isError']).to be true
      expect(result['result']['content'].first['text']).to include('Tool exploded')
    end
  end

  describe 'unknown method' do
    it 'returns -32601 method not found' do
      result = parse_response('{"jsonrpc":"2.0","id":11,"method":"foobar"}')
      expect(result['error']['code']).to eq(-32601)
    end
  end

  describe 'parse error' do
    it 'returns -32700 for invalid JSON' do
      result = parse_response('not valid json{{{')
      expect(result['error']['code']).to eq(-32700)
    end
  end

  describe 'internal error handling' do
    it 'returns -32603 on unexpected exceptions' do
      resource_class = Class.new(Mcp::BaseResource) do
        def uri; 'boom://resource'; end
        def name; 'Boom'; end
        def description; 'Explodes'; end
        def fetch_data(arguments, user)
          raise NoMethodError, 'something broke'
        end
      end

      server_with_boom = Mcp::Server.new(
        name: 'test', version: '1.0.0', user: user,
        resources: [resource_class]
      )
      body = '{"jsonrpc":"2.0","id":12,"method":"resources/read","params":{"uri":"boom://resource"}}'
      result = JSON.parse(server_with_boom.handle_request(body))
      expect(result['error']['code']).to eq(-32603)
    end
  end
end
