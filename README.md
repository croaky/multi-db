# multi-db

This is a Rails 6 app configured to
write to a Heroku Postgres database as a "primary"
and read from a Heroku Postgres "follower", a read-only replica.

## Design considerations

As a production Ruby on Rails app on Heroku scales,
you may want to move some database read load to a replica
in order to keep some web processes and their database connections
free for other read and write throughput.

As of Rails 6, the framework offers this via
[built-in facilities](https://guides.rubyonrails.org/active_record_multiple_databases.html).
This repo demonstrates one possible configuration of these facilities.

In this configuration, automatic connection switching is not enabled.
Instead, the replica can be used at call sites in the Rails app.
For example, it is used in `ThingsController#index`:

```ruby
def index
  ApplicationRecord.read_only do
    @things = Thing.order(created_at: :desc)
  end
end
```

This targeted approach is well-suited for moving load
such as admin read actions or search queries
that don't need to be consistent up to the second.
It, along with automatic connection switching, is not well-suited
for user flows where a user makes a write action
and needs to immediately see the read result
because of the race condition created by
a Heroku Postgres database under load
replicating while the read query comes in.

This is `app/models/application_record.rb`:

```ruby
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  FOLLOWER_COLOR = ENV["DATABASE_FOLLOWER_COLOR"].to_s.upcase
  FOLLOWER_URL = ENV["HEROKU_POSTGRESQL_#{FOLLOWER_COLOR}_URL"]

  if FOLLOWER_URL.present?
    connects_to database: {writing: :primary, reading: :follower}
  end

  def self.read_only
    if FOLLOWER_URL.present?
      ActiveRecord::Base.connected_to(role: :reading) do
        # All code in this block will run against the follower database.
        # If a write is attempted, an ActiveRecord::ReadOnlyError will raise.
        yield
      end
    else
      # All code in this block will run against the only configured database.
      # Database roles `primary` and `follower` are not available.
      yield
    end
  end
end
```

Heroku Postgres assigns a "color" identifier to each database
that is guaranteed to be unique within the Heroku app.
`ActiveRecord::ConnectionHandling#connects_to` is only invoked
if the follower database URL is present.

This is important because ActiveRecord will spawn a database pool for
each database "role" of `writing` and `reading` in this case.

If the configuration instead had a fallback for `follower` to
the `primary` Heroku database at `DATABASE_URL`,
we would double our database connections,
which max out at 500 at the highest Heroku Postgres plans.

The `primary` and `follower` databases are therefore
only defined in `config/database.yml` based on the same logic,
depending on the presence of the follower database URL:

```yml
<% pool = ENV.fetch("PUMA_THREADS", 5) %>
<% follower_color = ENV["DATABASE_FOLLOWER_COLOR"].to_s.upcase %>
<% follower_url = ENV["HEROKU_POSTGRESQL_#{follower_color}_URL"] %>

default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= pool %>

development:
  primary:
    <<: *default
    database: multi_db_development
  follower:
    <<: *default
    database: multi_db_development
    replica: true

test:
  <<: *default
  database: multi_db_test

production:
  <% if follower_url.present? %>
  primary:
    <<: *default
  follower:
    <<: *default
    replica: true
    url: <%= follower_url %>
  <% else %>
  <<: *default
  <% end %>
```

For sake of simplicity in this demo app,
the database pool is set to use `PUMA_THREADS` and
all the configurable environment variables are set to 5 by default.

```
DATABASE_FOLLOWER_COLOR=SILVER
PUMA_WORKERS=5
PUMA_THREADS=5
```

See `config/puma.rb`:

```ruby
workers ENV.fetch("PUMA_WORKERS", 5).to_i
threads_count = ENV.fetch("PUMA_THREADS", 5).to_i
threads threads_count, threads_count

preload_app!

rackup DefaultRackup
port ENV.fetch("PORT", 3000)
environment ENV.fetch("RAILS_ENV", "development")

on_worker_boot do
  ActiveRecord::Base.establish_connection
end
```

If your app is at the point of considering a read replica,
you may also be using Heroku's Performance dyno types.
If you kept the default `PUMA_WORKERS=5`,
at 400MB of memory for each Rails `web` process,
you'd be at 80% capacity using Performance-M dynos (2.5GB memory each).
If the dyno formation is `heroku ps:scale web=2`,
you'd be at 250 database connections, requiring
at least a `standard-2` Heroku Postgres database (400 connections each).

```
2 web dynos * 5 Puma workers * 5 Puma threads * 5 database connection pools =
250 maximum database connections
```

A final consideration is
if you have a High Availability (HA) Heroku Postgres follower,
should it be used as a read-only replica?
This is possible and would save money compared to
adding another replica strictly for reads.

If the HA fails over to primary,
the app will temporarily be configured to point both `primary` and `follower`
databases to the new primary database,
doubling the total database connections.
If you have headroom to double the connections temporarily
and feel you can update the `DATABASE_FOLLOWER_COLOR` environment variable
quickly after failover,
it may be worth the cost savings.

## Setup

Get it:

```
git clone git@github.com:croaky/multi-db.git
cd multi-db
```

Set up Ruby:

```
bundle install
```

Set up Postgres:

```
bundle exec rake db:create
bundle exec rake db:migrate
```

Run it:

```
rails server
```

Set up Heroku:

```
heroku create
heroku addons:create heroku-postgresql:standard-0
heroku pg:wait
```

Wait for primary to be ready.
Then, set up follower:

```
heroku addons:create heroku-postgresql:standard-0 --follow DATABASE_URL
heroku pg:wait
```

Wait for follower to be ready.
Get its color URL:

```
heroku pg:info
```

Set `DATABASE_FOLLOWER_COLOR` to the value of the follower's "color":

```
heroku config:set DATABASE_FOLLOWER_COLOR="SILVER"
```

Deploy:

```
git push heroku
```
