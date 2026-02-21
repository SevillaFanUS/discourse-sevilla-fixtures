# frozen_string_literal: true

require "net/http"
require "json"

module DiscourseSevillaFixtures
  # Wraps the football-data.org v4 REST API.
  # Fetches upcoming fixtures for a given team.
  #
  # Docs: https://www.football-data.org/documentation/api
  class FootballDataClient

    BASE_URL  = "https://api.football-data.org/v4"
    TIMEOUT   = 10 # seconds

    # ── Public Interface ──────────────────────────────────────────────────────

    # Returns an array of fixture hashes for the given team_id.
    # Each hash contains the raw fixture data from football-data.org.
    #
    # @param team_id [Integer] football-data.org team identifier (Sevilla FC = 559)
    # @return [Array<Hash>]
    def fetch_upcoming_fixtures(team_id:)
      response = get("/teams/#{team_id}/matches", { status: "SCHEDULED,TIMED" })
      return [] unless response

      matches = response.dig("matches") || []
      Rails.logger.info("[SevillaFixtures] Fetched #{matches.size} upcoming fixture(s) for team #{team_id}")
      matches
    rescue StandardError => e
      Rails.logger.error("[SevillaFixtures] FootballDataClient error: #{e.message}")
      []
    end

    # ── Private Helpers ───────────────────────────────────────────────────────

    private

    def api_key
      SiteSetting.sevilla_fixtures_football_data_api_key
    end

    # Performs a GET request to the football-data.org API.
    #
    # @param path [String]   e.g. "/teams/559/matches"
    # @param params [Hash]   optional query-string parameters
    # @return [Hash, nil]    parsed JSON body, or nil on error
    def get(path, params = {})
      uri = build_uri(path, params)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl       = true
      http.read_timeout  = TIMEOUT
      http.open_timeout  = TIMEOUT

      request = Net::HTTP::Get.new(uri)
      request["X-Auth-Token"] = api_key
      request["Accept"]       = "application/json"

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error(
          "[SevillaFixtures] football-data.org returned #{response.code} for #{uri}"
        )
        return nil
      end

      JSON.parse(response.body)
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      Rails.logger.error("[SevillaFixtures] Request timed out: #{e.message}")
      nil
    rescue JSON::ParserError => e
      Rails.logger.error("[SevillaFixtures] JSON parse error: #{e.message}")
      nil
    end

    def build_uri(path, params)
      uri = URI("#{BASE_URL}#{path}")
      uri.query = URI.encode_www_form(params) if params.any?
      uri
    end
  end
end
