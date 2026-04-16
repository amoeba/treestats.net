web: bundle exec puma
resque: env TERM_CHILD=1 bundle exec rake resque:work
clock: bundle exec clockwork lib/clock.rb
sidekiq: bundle exec sidekiq -r ./lib/sidekiq_boot.rb
