# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseSevillaFixtures::FixtureSyncService do
  let(:client)  { instance_double(DiscourseSevillaFixtures::FootballDataClient) }
  let(:builder) { DiscourseSevillaFixtures::FixturePostBuilder.new }
  let(:service) { described_class.new(client: client, builder: builder) }

  before do
    SiteSetting.sevilla_fixtures_enabled          = true
    SiteSetting.sevilla_fixtures_team_id          = 559
    SiteSetting.sevilla_fixtures_category_id      = 1
    SiteSetting.sevilla_fixtures_days_ahead       = 14
    SiteSetting.sevilla_fixtures_post_username    = "system"
    SiteSetting.sevilla_fixtures_tags             = "sevilla-fc,match-thread"
    SiteSetting.sevilla_fixtures_event_timezone   = "Europe/Madrid"
  end

  describe "#run" do
    context "when plugin is disabled" do
      before { SiteSetting.sevilla_fixtures_enabled = false }

      it "does not call the API client" do
        expect(client).not_to receive(:fetch_upcoming_fixtures)
        service.run
      end
    end

    context "when API returns fixtures" do
      let(:raw_fixture) do
        {
          "id"          => 12345,
          "status"      => "SCHEDULED",
          "utcDate"     => 7.days.from_now.utc.iso8601,
          "competition" => { "name" => "La Liga" },
          "homeTeam"    => { "name" => "Sevilla FC" },
          "awayTeam"    => { "name" => "Real Madrid CF" },
          "season"      => { "startDate" => "2024-08-01" },
          "venue"       => "Estadio Ramón Sánchez-Pizjuán"
        }
      end

      before do
        allow(client).to receive(:fetch_upcoming_fixtures).and_return([raw_fixture])
        allow(PostCreator).to receive(:create!).and_return(
          double("Post", topic_id: 999)
        )
      end

      it "creates a SevillaFixture record" do
        expect { service.run }.to change(SevillaFixture, :count).by(1)
      end

      it "sets the external_id from the API response" do
        service.run
        expect(SevillaFixture.find_by(external_id: 12345)).to be_present
      end

      it "creates a Discourse topic and stores the topic_id" do
        service.run
        fixture = SevillaFixture.find_by(external_id: 12345)
        expect(fixture.discourse_topic_id).to eq(999)
      end

      context "when the fixture was already posted" do
        before do
          SevillaFixture.create!(
            external_id:        12345,
            competition:        "La Liga",
            home_team:          "Sevilla FC",
            away_team:          "Real Madrid CF",
            status:             "SCHEDULED",
            season:             2024,
            kickoff_at:         7.days.from_now.utc,
            discourse_topic_id: 42
          )
        end

        it "does not create a duplicate topic" do
          expect(PostCreator).not_to receive(:create!)
          service.run
        end
      end

      context "when the fixture kickoff is beyond the look-ahead window" do
        let(:raw_fixture) do
          super().merge("utcDate" => 30.days.from_now.utc.iso8601)
        end

        it "saves the fixture but does not post a topic" do
          expect(PostCreator).not_to receive(:create!)
          service.run
          expect(SevillaFixture.find_by(external_id: 12345)).to be_present
        end
      end
    end
  end
end
