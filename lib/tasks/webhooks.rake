namespace :webhooks do
  desc "Process due webhook events; stop cleanly on TERM or INT"
  task work: :environment do
    running = true
    %w[INT TERM].each { |signal| Signal.trap(signal) { running = false } }
    processor = EventProcessor.new
    puts "Webhook worker started"
    while running
      worked = processor.run_once
      sleep 0.5 unless worked
    end
    puts "Webhook worker stopped"
  end
end
