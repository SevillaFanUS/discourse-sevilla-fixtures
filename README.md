# discourse-sevilla-fixtures

A Discourse plugin for **MonchisMen.com** that automatically creates match-thread topics and calendar Events for every Sevilla FC fixture once a date and time are confirmed by football-data.org.

---

## How It Works

A Sidekiq background job runs every **6 hours**. On each run it:

1. Calls the **football-data.org** API to fetch upcoming Sevilla FC fixtures (`SCHEDULED` / `TIMED` status)
2. Upserts each fixture into a local `sevilla_fixtures` table (updates status & kickoff as they change)
3. For any fixture that:
   - has a confirmed kickoff date/time
   - falls within the configured look-ahead window (default: 14 days)
   - has not yet been posted
   …it creates a **Discourse topic** in the configured category, complete with:
   - A structured match-info table
   - An `[event][/event]` block for the **Discourse Events plugin** calendar
   - Discussion prompts
4. Stores the returned `topic_id` so the fixture is never double-posted

---

## Requirements

| Requirement | Notes |
|---|---|
| Discourse | Latest stable |
| Discourse Events Plugin | github.com/angusmcleod/discourse-events |
| football-data.org account | Free tier is sufficient |
| Ruby | 3.x (matches Discourse) |

---

## Installation

### 1. SSH into your DigitalOcean droplet

```bash
ssh root@your-droplet-ip
cd /var/discourse
```

### 2. Clone the plugin into Discourse's plugins directory

```bash
git clone https://github.com/YOUR_USERNAME/discourse-sevilla-fixtures.git \
  plugins/discourse-sevilla-fixtures
```

### 3. Rebuild the Discourse container

```bash
./launcher rebuild app
```

This runs the database migration automatically and registers the scheduled job with Sidekiq.

---

## Configuration

All settings are in **Admin → Settings → Plugins** (search "sevilla"):

| Setting | Description | Default |
|---|---|---|
| `sevilla_fixtures_enabled` | Master on/off switch | `false` |
| `sevilla_fixtures_football_data_api_key` | Your football-data.org API key | *(empty)* |
| `sevilla_fixtures_team_id` | Sevilla FC's team ID on football-data.org | `559` |
| `sevilla_fixtures_category_id` | Discourse category ID for match threads | `0` |
| `sevilla_fixtures_post_username` | Author of the auto-created posts | `system` |
| `sevilla_fixtures_days_ahead` | Days ahead to look for fixtures to post | `14` |
| `sevilla_fixtures_event_timezone` | Timezone for event start/end times | `Europe/Madrid` |
| `sevilla_fixtures_tags` | Comma-separated tags for each topic | `sevilla-fc,match-thread` |

### Finding your Category ID

Go to your target category in Discourse, click **Edit**, and the ID is in the URL:
`/c/edit/YOUR_CATEGORY_ID`

### Getting a football-data.org API Key

1. Register free at https://www.football-data.org/
2. Your API key is shown in your dashboard immediately
3. Paste it into the `sevilla_fixtures_football_data_api_key` setting

---

## Manual Trigger (Rails Console)

You can trigger a sync immediately from the Discourse Rails console:

```bash
cd /var/discourse
./launcher enter app
rails console
```

```ruby
# Trigger a full sync now
Jobs::SyncSevillaFixtures.new.execute({})

# Check what fixtures have been stored
SevillaFixture.all.map { |f| "#{f.home_team} vs #{f.away_team} | #{f.kickoff_at} | topic_id: #{f.discourse_topic_id}" }

# Check unposted upcoming fixtures
SevillaFixture.unposted.schedulable.upcoming_within(30).count

# Reset a fixture to re-post it (use with care)
SevillaFixture.find_by(external_id: 12345).update!(discourse_topic_id: nil)
```

---

## Post Format

Each auto-created topic looks like:

**Title:** `🇪🇸 Match Thread | Sevilla FC vs Atlético Madrid – La Liga`

**Body:**
```
[event start="2025-03-15 21:00" end="2025-03-15 23:00" status="public" timezone="Europe/Madrid" allowedGroups="trust_level_0"]
[/event]

## Match Details

| | |
|---|---|
| Competition | La Liga |
| Home | Sevilla FC |
| Away | Atlético Madrid |
| Kickoff | Saturday, March 15 2025 at 21:00 CET |
| Venue | Estadio Ramón Sánchez-Pizjuán |

## Match Thread

Use this thread to discuss...
```

---

## Plugin File Structure

```
discourse-sevilla-fixtures/
├── plugin.rb                                         ← Entry point
├── config/
│   └── settings.yml                                  ← Admin-panel settings
├── app/
│   └── jobs/
│       └── scheduled/
│           └── sync_sevilla_fixtures.rb              ← Sidekiq job (every 6h)
├── lib/
│   └── discourse_sevilla_fixtures/
│       ├── sevilla_fixture.rb                        ← ActiveRecord model
│       ├── football_data_client.rb                   ← football-data.org HTTP client
│       ├── fixture_post_builder.rb                   ← Builds title + raw post body
│       └── fixture_sync_service.rb                   ← Orchestration service
├── db/
│   └── migrate/
│       └── 20240101000000_create_sevilla_fixtures.rb ← DB migration
└── spec/
    ├── fixture_sync_service_spec.rb
    └── fixture_post_builder_spec.rb
```

---

## Updating the Plugin

```bash
cd /var/discourse/plugins/discourse-sevilla-fixtures
git pull origin main
cd /var/discourse
./launcher rebuild app
```

---

## Troubleshooting

**Posts not appearing:**
- Check `sevilla_fixtures_enabled` is `true`
- Verify `sevilla_fixtures_category_id` is set correctly
- Check Sidekiq is running: Admin → Sidekiq → Scheduled
- Check Rails logs: `./launcher logs app | grep SevillaFixtures`

**Events not showing on calendar:**
- Ensure the Discourse Events plugin is installed and enabled
- The posting user (default: `system`) must have permission to create events
- Check that your category has Events enabled in its settings

**API errors:**
- Verify your football-data.org API key is correct
- Free tier allows 10 requests/minute — the 6-hour scheduler uses 1 request per run
