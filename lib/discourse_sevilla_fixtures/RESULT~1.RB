# frozen_string_literal: true

module DiscourseSevillaFixtures
  # Fetches recently finished matches.
  #
  # Subclasses the existing FootballDataClient purely to reuse its `get`
  # helper (auth headers, timeouts, error handling) rather than
  # duplicating that boilerplate — private methods are inherited and
  # callable from a subclass.
  class ResultsClient < FootballDataClient
    # Only look a few days back. A finished match that somehow never got
    # its result posted within this window isn't worth resurrecting
    # automatically — post it by hand rather than having the job
    # bump an ancient topic unexpectedly.
    DEFAULT_DAYS_BACK = 5

    def fetch_recent_results(team_id:, days_back: DEFAULT_DAYS_BACK)
      response =
        get(
          "/teams/#{team_id}/matches",
          {
            status: "FINISHED",
            dateFrom: (Date.current - days_back).to_s,
            dateTo: (Date.current + 1).to_s,
          },
        )
      return [] unless response

      matches = response["matches"] || []
      Rails.logger.info(
        "[SevillaFixtures] Fetched #{matches.size} finished match(es) for team #{team_id}",
      )
      matches
    rescue StandardError => e
      Rails.logger.error("[SevillaFixtures] ResultsClient error: #{e.message}")
      []
    end
  end
end
