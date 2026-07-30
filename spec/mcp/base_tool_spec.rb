# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::BaseTool do
  subject(:tool) { described_class.new }

  describe 'NotImplementedError contracts' do
    it 'raises on #name' do
      expect { tool.name }.to raise_error(NotImplementedError, /#name/)
    end

    it 'raises on #description' do
      expect { tool.description }.to raise_error(NotImplementedError, /#description/)
    end

    it 'raises on #input_schema' do
      expect { tool.input_schema }.to raise_error(NotImplementedError, /#input_schema/)
    end

    it 'raises on #call' do
      expect { tool.call({}, nil) }.to raise_error(NotImplementedError, /#call/)
    end
  end
end
