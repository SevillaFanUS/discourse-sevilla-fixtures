# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseSevillaFixtures::FixturePostBuilder do
  let(:builder) { described_class.new }

  let(:fixture) do
    SevillaFixture.new(
      competition: "La Liga",
      home_team:   "Sevilla FC",
      away_team:   "Atlético Madrid",
      kickoff_at:  Time.utc(2025, 3, 15, 20, 0, 0),
      venue:       "Estadio Ramón Sánchez-Pizjuán",
      status:      "SCHEDULED"
    )
  end

  before do
    SiteSetting.sevilla_fixtures_event_timezone = "America/New_York"
  end

  describe "#build" do
    subject(:result) { builder.build(fixture) }

    it "returns a hash with :title and :raw keys" do
      expect(result).to include(:title, :raw)
    end

    describe ":title" do
      it "includes both team names" do
        expect(result[:title]).to include("Sevilla FC", "Atlético Madrid")
      end

      it "includes the competition name" do
        expect(result[:title]).to include("La Liga")
      end

      it "includes a La Liga emoji" do
        expect(result[:title]).to include("🇪🇸")
      end
    end

    describe ":raw" do
      it "includes an [event] BBCode block" do
        expect(result[:raw]).to include("[event ")
        expect(result[:raw]).to include("[/event]")
      end

      it "includes the kickoff start time in the event tag" do
        # 20:00 UTC = 21:00 Europe/Madrid (CET, UTC+1 in March)
        expect(result[:raw]).to include('start="2025-03-15 21:00"')
      end

      it "includes the venue in the match info table" do
        expect(result[:raw]).to include("Estadio Ramón Sánchez-Pizjuán")
      end

      it "includes the competition in the match info table" do
        expect(result[:raw]).to include("La Liga")
      end
    end
  end
end
