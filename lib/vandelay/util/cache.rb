require 'redis'

module Vandelay
  module Util
    class Cache
      def initialize
        @redis = Redis.new
      end

      def set(key, value, ttl = 600)
        @redis.set(key, value.to_json)
        @redis.expire(key, ttl)
      end

      def get(key)
        cached_value = @redis.get(key)
        JSON.parse(cached_value) if cached_value
      end

      def delete(key)
        @redis.del(key)
      end
    end
  end
end
