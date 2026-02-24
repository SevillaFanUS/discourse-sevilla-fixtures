# frozen_string_literal: true

module DiscourseSevillaFixtures
  # Orchestrates the full sync cycle:
  #   1. Fetch upcoming Sevilla FC fixtures from football-data.org
  #   2. Upsert fixture records into the local DB
  #   3. For fixtures within the look-ahead window that have no Discourse
  #      topic yet, create the topic + Events-plugin event
  #   4. Persist the returned topic ID so the fixture is not double-posted
  class FixtureSyncService

    # ── Public Interface ──────────────────────────────────────────────────────

    def initialize(
      client:  DiscourseSevillaFixtures::FootballDataClient.new,
      builder: DiscourseSevillaFixtures::FixturePostBuilder.new
    )
      @client  = client
      @builder = builder
    end

    # Entry point called by the scheduled job.
    def run
      unless SiteSetting.sevilla_fixtures_enabled
        Rails.logger.info("[SevillaFixtures] Plugin disabled – skipping sync")
        return
      end

      team_id = SiteSetting.sevilla_fixtures_team_id
      raw_fixtures = @client.fetch_upcoming_fixtures(team_id: team_id)

      upsert_fixtures(raw_fixtures)
      post_pending_fixtures
    rescue StandardError => e
      Rails.logger.error("[SevillaFixtures] FixtureSyncService#run failed: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    end

    # ── Private Helpers ───────────────────────────────────────────────────────

    private

    # Inserts new fixtures or updates the status/kickoff of existing ones.
    # We intentionally avoid clobbering discourse_topic_id on existing records.
    def upsert_fixtures(raw_fixtures)
      raw_fixtures.each do |raw|
        external_id = raw["id"]
        next unless external_id

        fixture = ::SevillaFixture.find_or_initialize_by(external_id: external_id)
        assign_fixture_attributes(fixture, raw)
        fixture.save!
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error("[SevillaFixtures] Could not save fixture #{external_id}: #{e.message}")
      end
    end

    # Maps raw football-data.org JSON onto a SevillaFixture record.
    def assign_fixture_attributes(fixture, raw)
      fixture.uuid = SecureRandom.uuid if fixture.new_record?

      fixture.competition         = raw.dig("competition", "name").to_s
      fixture.competition_emblem  = raw.dig("competition", "emblem").to_s.presence
      fixture.home_team           = raw.dig("homeTeam", "name").to_s
      fixture.home_team_crest     = raw.dig("homeTeam", "crest").to_s.presence
      fixture.away_team           = raw.dig("awayTeam", "name").to_s
      fixture.away_team_crest     = raw.dig("awayTeam", "crest").to_s.presence
      fixture.matchday            = raw.dig("matchday")
      fixture.status              = raw["status"].to_s
      fixture.season              = raw.dig("season", "startDate")&.to_date&.year.to_i
      fixture.venue               = raw.dig("venue").to_s.presence

      # kickoff_at: the API returns an ISO-8601 string in UTC
      utc_date = raw["utcDate"]
      fixture.kickoff_at = utc_date ? Time.parse(utc_date).utc : nil
    end

    # Finds all fixtures that:
    #   - have a confirmed kickoff within the configured look-ahead window
    #   - are SCHEDULED or TIMED (not postponed/cancelled)
    #   - have NOT yet been posted to Discourse
    # Then creates the topic + event for each one.
    def post_pending_fixtures
      days_ahead = SiteSetting.sevilla_fixtures_days_ahead

      # Reset discourse_topic_id for any fixtures whose topic has been deleted
      ::SevillaFixture.where.not(discourse_topic_id: nil).each do |fixture|
        unless Topic.exists?(id: fixture.discourse_topic_id, deleted_at: nil)
          fixture.update_columns(discourse_topic_id: nil)
          Rails.logger.info("[SevillaFixtures] Reset topic ID for fixture #{fixture.external_id} – topic was deleted")
        end
      end

      pending = ::SevillaFixture
                  .unposted
                  .schedulable
                  .upcoming_within(days_ahead)
                  .order(:kickoff_at)

      Rails.logger.info("[SevillaFixtures] #{pending.size} fixture(s) pending Discourse post")

      pending.each do |fixture|
        topic_id = create_discourse_topic(fixture)
        if topic_id
          fixture.update!(discourse_topic_id: topic_id)
          Rails.logger.info("[SevillaFixtures] Created topic ##{topic_id} for fixture #{fixture.external_id} (#{fixture.home_team} vs #{fixture.away_team})")
        end
      end
    end

    # Creates a Discourse topic using PostCreator (Discourse's internal API).
    # The raw post body includes the [event] tag for the Events plugin.
    #
    # @param fixture [SevillaFixture]
    # @return [Integer, nil] the created topic's ID, or nil on failure
    def create_discourse_topic(fixture)
      author   = resolve_author
      content  = @builder.build(fixture)
      tags     = parse_tags

      post = PostCreator.create!(
        author,
        title:              content[:title],
        raw:                content[:raw],
        category:           SiteSetting.sevilla_fixtures_category_id,
        tags:               tags,
        skip_validations:   true,
        skip_guardian:      true
      )

      post&.topic_id
    rescue PostCreator::FailedToCreatePost => e
      Rails.logger.error("[SevillaFixtures] PostCreator failed for fixture #{fixture.external_id}: #{e.message}")
      nil
    rescue StandardError => e
      Rails.logger.error("[SevillaFixtures] Unexpected error creating topic for fixture #{fixture.external_id}: #{e.message}")
      nil
    end

    # Resolves the Discourse User that will author the posts.
    # Falls back to the system user if the configured username is not found.
    def resolve_author
      username = SiteSetting.sevilla_fixtures_post_username
      User.find_by(username: username) || Discourse.system_user
    end

    # Parses the comma-separated tag setting into an array.
    def parse_tags
      SiteSetting.sevilla_fixtures_tags
                 .split(",")
                 .map(&:strip)
                 .reject(&:empty?)
    end
  end
end