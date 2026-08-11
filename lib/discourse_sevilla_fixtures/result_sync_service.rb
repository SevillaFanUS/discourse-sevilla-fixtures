# frozen_string_literal: true

module DiscourseSevillaFixtures
  # Builds the full-time reply posted into an existing match thread, and
  # the new topic title that replaces "Match Thread | …" once the result
  # is known.
  #
  # Pure formatting — no API calls, no posting — so the output can be
  # checked from the rails console before trusting it to a job.
  class ResultPostBuilder
    def initialize(fixture)
      @fixture = fixture
    end

    # "Sevilla FC 2-1 Real Betis | La Liga"
    #
    # Retitling matters beyond the forum: a topic called
    # "Match Thread | Sevilla FC vs Real Betis" is invisible to anyone
    # searching for the score afterwards.
    def topic_title
      "#{@fixture.home_team} #{home_score}-#{away_score} #{@fixture.away_team} | #{@fixture.competition}"
    end

    def reply_body
      <<~MARKDOWN.strip
        ## Full time

        **#{@fixture.home_team} #{home_score}–#{away_score} #{@fixture.away_team}**

        #{outcome_line}

        #{competition_line}
      MARKDOWN
    end

    private

    def home_score
      @fixture.home_score.to_i
    end

    def away_score
      @fixture.away_score.to_i
    end

    # Reads from the club's perspective rather than just stating the score
    # again — "Sevilla win" is what a member actually wants to see.
    def outcome_line
      club = club_is_home? ? @fixture.home_team : @fixture.away_team
      club_goals = club_is_home? ? home_score : away_score
      other_goals = club_is_home? ? away_score : home_score

      if club_goals > other_goals
        "#{club} win #{club_goals}–#{other_goals} against #{@fixture.opponent}."
      elsif club_goals < other_goals
        "#{club} lose #{club_goals}–#{other_goals} to #{@fixture.opponent}."
      else
        "#{club} draw #{club_goals}–#{other_goals} with #{@fixture.opponent}."
      end
    end

    def competition_line
      venue = @fixture.venue.presence
      parts = [@fixture.competition.presence, venue].compact
      parts.any? ? "*#{parts.join(" · ")}*" : ""
    end

    def club_is_home?
      @fixture.respond_to?(:home_game?) ? @fixture.home_game? : true
    end
  end
end
