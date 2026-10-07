threads_count = ENV.fetch("RAILS_MAX_THREADS", 5).to_i
threads threads_count, threads_count

port ENV.fetch("PORT", 3000)
workers ENV.fetch("WEB_CONCURRENCY", 0).to_i

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
plugin :tmp_restart
