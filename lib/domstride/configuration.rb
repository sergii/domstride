module Domstride
  module Configuration
    DEFAULTS = {
      runtime: "node", engine: "jsdom", profile: false, wait_strategy: "poll",
      bundle_cache: "off", settling: "checkpoint", clock: "real",
      clock_epoch_ms: 1_700_000_000_000, query_prefetch: false, assets: "off", asset_warnings: "strict", media_profile: "off", dom_profile: "off", observer_profile: "off", websocket_url: nil, websocket_cookie_names: nil, websocket_path_mode: "exact"
    }.freeze
    PROFILES = {
      "compatible" => { engine: "jsdom31" }.freeze,
      "fast" => { engine: "happy-dom" }.freeze,
      "deterministic" => { engine: "jsdom31", wait_strategy: "observer", bundle_cache: "compiled",
                           settling: "tracked", clock: "virtual" }.freeze
    }.freeze
    ENV_KEYS = {
      runtime: "DOMSTRIDE_RUNTIME", engine: "DOMSTRIDE_ENGINE", profile: "DOMSTRIDE_PROFILE",
      wait_strategy: "DOMSTRIDE_WAIT", bundle_cache: "DOMSTRIDE_BUNDLE_CACHE",
      settling: "DOMSTRIDE_SETTLING", clock: "DOMSTRIDE_CLOCK",
      query_prefetch: "DOMSTRIDE_QUERY_PREFETCH", assets: "DOMSTRIDE_ASSETS", asset_warnings: "DOMSTRIDE_ASSET_WARNINGS", media_profile: "DOMSTRIDE_MEDIA_PROFILE", dom_profile: "DOMSTRIDE_DOM_PROFILE", observer_profile: "DOMSTRIDE_OBSERVER_PROFILE", websocket_url: "DOMSTRIDE_WEBSOCKET_URL", websocket_cookie_names: "DOMSTRIDE_WEBSOCKET_COOKIE_NAMES", websocket_path_mode: "DOMSTRIDE_WEBSOCKET_PATH_MODE"
    }.freeze

    def self.resolve(performance_profile: nil, env: ENV, **overrides)
      name = performance_profile || env["DOMSTRIDE_PERFORMANCE_PROFILE"]
      profile = name ? PROFILES.fetch(name.to_s) { raise ArgumentError, "Unknown performance profile: #{name}" } : {}
      unknown = overrides.keys - DEFAULTS.keys
      raise ArgumentError, "Unknown options: #{unknown.join(', ')}" unless unknown.empty?
      values = DEFAULTS.merge(profile)
      ENV_KEYS.each do |key, variable|
        next unless env.key?(variable)
        values[key] = %i[profile query_prefetch].include?(key) ? env[variable] == "1" : env[variable]
      end
      values.merge(overrides)
    end
  end
end
