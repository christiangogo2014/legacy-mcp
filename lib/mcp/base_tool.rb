module Mcp
  class BaseTool
    def name
      raise NotImplementedError, 'Subclasses must implement #name'
    end

    def description
      raise NotImplementedError, 'Subclasses must implement #description'
    end

    def input_schema
      raise NotImplementedError, 'Subclasses must implement #input_schema'
    end

    def call(arguments, user)
      raise NotImplementedError, 'Subclasses must implement #call'
    end
  end
end
