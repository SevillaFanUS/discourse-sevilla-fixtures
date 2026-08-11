# frozen_string_literal: true

module DiscourseSevillaFixtures
  # Closes the loop on match threads: once a fixture finishes, posts the
  # full-time score into the thread that was created for it and retitles
  # the topic from "Match Thread | Sevilla vs Betis" to
  # "Sevilla 2-1 Betis | La Liga".
  #
  # Without this, every match thread is left permanently showing a
  # pre-match preview table.
  class ResultSyncService
    def run!
      return unless SiteSetting.sevilla_fixtures_enabled
      return if SiteSetting.sevilla_fixtures_football_data_api_key.blank?

      team_id = SiteSetting.sevilla_fixtures_team_id.presence || 559
      matches = ResultsClient.new.fetch_recent_results(team_id: team_id)
      return if matches.blank?

      matches.each { |match| process(match) }
    end

    private

    def process(match)
      fixture = SevillaFixture.find_by(external_id: match["id"])

      # No local record, or we never created a thread for it — nothing to
      # post into.
      return if fixture.nil? || fixture.discourse_topic_id.blank?

      # Already handled.
      return if fixture.result_posted_at.present?

      home = match.dig("score", "fullTime", "home")
      away = match.dig("score", "fullTime", "away")
      return if home.nil? || away.nil?

      topic = Topic.find_by(id: fixture.discourse_topic_id)
      if topic.nil?
        Rails.logger.warn(
          "[SevillaFixtures] Topic #{fixture.discourse_topic_id} for fixture #{fixture.external_id} is gone; skipping result",
        )
        return
      end

      fixture.update!(status: match["status"], home_score: home, away_score: away)

      builder = ResultPostBuilder.new(fixture)
      post_result(topic, builder)
      retitle(topic, builder) if SiteSetting.sevilla_fixtures_retitle_on_result

      fixture.update!(result_posted_at: Time.current)

      Rails.logger.info(
        "[SevillaFixtures] Posted result for fixture #{fixture.external_id} into topic #{topic.id}",
      )
    rescue => e
      Rails.logger.error(
        "[SevillaFixtures] Failed to post result for match #{match["id"]}: #{e.class}: #{e.message}",
      )
    end

    def post_result(topic, builder)
      PostCreator.create!(
        posting_user,
        topic_id: topic.id,
        raw: builder.reply_body,
        skip_validations: true,
      )
    end

    # Title changes have to go through PostRevisor rather than a raw
    # update so the slug, search index and topic history stay consistent.
    def retitle(topic, builder)
      first_post = topic.first_post
      return if first_post.nil?

      PostRevisor.new(first_post, topic).revise!(
        posting_user,
        { title: builder.topic_title },
        skip_validations: true,
        bypass_bump: false,
      )
    end

    # Matches whatever the fixtures plugin posts match threads as, falling
    # back to the system user.
    def posting_user
      username = SiteSetting.sevilla_fixtures_post_username.presence
      (username && User.find_by(username: username)) || Discourse.system_user
    end
  end
end
