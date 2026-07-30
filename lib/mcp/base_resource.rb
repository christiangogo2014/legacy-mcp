module Mcp
  class BaseResource
    def uri
      raise NotImplementedError, 'Subclasses must implement #uri'
    end

    def name
      raise NotImplementedError, 'Subclasses must implement #name'
    end

    def description
      raise NotImplementedError, 'Subclasses must implement #description'
    end

    def mime_type
      'application/json'
    end

    def read(arguments = {}, user = nil)
      {
        uri: uri,
        mimeType: mime_type,
        text: fetch_data(arguments, user).to_json
      }
    end

    def fetch_data(arguments, user)
      raise NotImplementedError, 'Subclasses must implement #fetch_data'
    end

    protected

    def require_argument(arguments, key)
      raise ArgumentError, "Missing required argument: #{key}" unless arguments.key?(key.to_s)
      arguments[key.to_s]
    end

    def optional_argument(arguments, key, default = nil)
      arguments.fetch(key.to_s, default)
    end
  end
end
