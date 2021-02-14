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
