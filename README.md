# multi-db

This is a Rails 6 app configured to
write to a Heroku Postgres database as a "primary"
and read from a Heroku Postgres "follower", a read-only replica.

## Design considerations

See this article
[Heroku Postgres Read Replica with Rails](https://dancroak.com/heroku-postgres-read-replica-with-rails).

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
