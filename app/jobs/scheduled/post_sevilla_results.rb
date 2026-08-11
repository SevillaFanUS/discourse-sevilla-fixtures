# frozen_string_literal: true

module ::Jobs
  # Runs every 30 minutes. Matches are only checked in a short recent
  # window and each fixture is posted once (guarded by result_posted_at),
  # so frequent runs are cheap — one API call per run.
  class PostSevillaResults < ::Jobs::Scheduled
    every 30.minutes

    def execute(_args)
      return unless SiteSetting.sevilla_fixtures_enabled
      return unless SiteSetting.sevilla_fixtures_post_results

      DiscourseSevillaFixtures::ResultSyncService.new.run!
    rescue => e
      Rails.logger.error("[SevillaFixtures] Result job failed: #{e.class}: #{e.message}")
    end
  end
end
