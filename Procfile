mongo: docker run -p 27017:27017 mongo
redis: redis-server
web: bundle exec puma
resque: env TERM_CHILD=1 bundle exec rake resque:work
clock: bundle exec clockwork lib/clock.rb

