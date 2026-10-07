namespace :board do
  desc "Rebuild the board from MySQL if it is missing from Redis (run at boot)"
  task ensure: :environment do
    puts "board: #{BoardRebuilder.ensure!}"
  end

  # Stop traffic first: placements made while this runs are overwritten in Redis.
  desc "Rebuild the board from MySQL even if it already exists in Redis"
  task rebuild: :environment do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = BoardRebuilder.rebuild!
    seconds = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(3)
    puts "rebuilt to seq #{result.seq}: #{result.events_replayed} events replayed " \
         "on top of #{result.snapshot_seq ? "snapshot #{result.snapshot_seq}" : 'a blank board'} in #{seconds}s"
  end

  desc "Compare the live board with a full replay of the history. Exits 1 on any difference"
  task check: :environment do
    report = ConsistencyChecker.run
    puts "live seq:        #{report.live_seq}"
    puts "events replayed: #{report.events_replayed}"
    puts "unrecorded:      #{report.unrecorded}"
    puts "differences:     #{report.differences}"
    exit 1 unless report.consistent?
  end

  desc "Take a snapshot of the board now"
  task snapshot: :environment do
    SnapshotJob.perform_now
    latest = BoardSnapshot.latest
    puts latest ? "latest snapshot is at seq #{latest.seq}" : "no snapshot taken: the board is missing"
  end

  desc "Draw a small heart on an empty board (FORCE=1 to draw on a used board)"
  task seed: :environment do
    puts "seeded #{BoardSeeder.run(force: ENV['FORCE'] == '1')} pixels"
  end
end
