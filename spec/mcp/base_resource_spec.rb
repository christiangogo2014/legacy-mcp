# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::BaseResource do
  subject(:resource) { described_class.new }

  describe 'default mime_type' do
    it 'returns application/json' do
      expect(resource.mime_type).to eq('application/json')
    end
  end

  describe 'NotImplementedError contracts' do
    it 'raises on #uri' do
      expect { resource.uri }.to raise_error(NotImplementedError, /#uri/)
    end

    it 'raises on #name' do
      expect { resource.name }.to raise_error(NotImplementedError, /#name/)
    end

    it 'raises on #description' do
      expect { resource.description }.to raise_error(NotImplementedError, /#description/)
    end

    it 'raises on #fetch_data' do
      expect { resource.fetch_data({}, nil) }.to raise_error(NotImplementedError, /#fetch_data/)
    end
  end

  describe '#read' do
    let(:subclass) do
      Class.new(described_class) do
        def uri; 'test://data'; end
        def name; 'Test'; end
        def description; 'Test resource'; end
        def fetch_data(arguments, user)
          { value: 42, arg: arguments['key'] }
        end
      end
    end

    it 'wraps fetch_data into a content hash with uri and mimeType' do
      result = subclass.new.read({}, nil)
      expect(result[:uri]).to eq('test://data')
      expect(result[:mimeType]).to eq('application/json')
      expect(JSON.parse(result[:text])).to eq('value' => 42, 'arg' => nil)
    end
  end

  describe 'argument helpers' do
    let(:subclass) do
      Class.new(described_class) do
        def uri; 'test://args'; end
        def name; 'Args'; end
        def description; 'Args'; end
        def fetch_data(arguments, user)
          required = require_argument(arguments, :card_id)
          optional = optional_argument(arguments, :filter, 'all')
          { required: required, optional: optional }
        end
      end
    end

    it 'extracts required argument by symbol key' do
      result = subclass.new.fetch_data({ 'card_id' => 5 }, nil)
      expect(result[:required]).to eq(5)
    end

    it 'raises ArgumentError when required argument is missing' do
      expect { subclass.new.fetch_data({}, nil) }.to raise_error(ArgumentError, /card_id/)
    end

    it 'returns default for optional argument' do
      result = subclass.new.fetch_data({ 'card_id' => 1 }, nil)
      expect(result[:optional]).to eq('all')
    end

    it 'returns provided value for optional argument' do
      result = subclass.new.fetch_data({ 'card_id' => 1, 'filter' => 'active' }, nil)
      expect(result[:optional]).to eq('active')
    end
  end
end
