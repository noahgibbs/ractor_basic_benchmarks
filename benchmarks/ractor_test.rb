#!/usr/bin/env ruby

require 'socket'
require 'json'
require 'fileutils'

require_relative "./do_work.rb"

QUERY_TEXT = "DO_WORK".freeze
RESPONSE_TEXT = do_work.freeze

if ARGV.size != 3
  STDERR.puts "Usage: ./thread_test <num_workers> <num_requests> <outfile>"
  exit 1
end

NUM_WORKERS = ARGV[0].to_i
NUM_REQUESTS = ARGV[1].to_i
OUTFILE = ARGV[2]
workers = []

def idx_to_path(i)
  "/tmp/ractor_test_#{i}.json"
end

NUM_WORKERS.times.each { |i| FileUtils.rm_f idx_to_path(i) }

working_t0 = Time.now

puts "Set up Ractors"
workers = NUM_WORKERS.times.map do |index|
  Ractor.new(index) do |worker_index|
    # Worker code
    output = []
    NUM_REQUESTS.times do
      response = do_work
      output << response
    end
    puts "Returning output from Ractor #{worker_index}..."
    File.open(idx_to_path(worker_index), "w") do |f|
      f.print output.inspect
    end
    output
  end
end

### Master code ###

#loop do
  #puts "Preparing to select from #{workers.size} workers..."
  #ractor, ret_val = Ractor.select(*workers)
  #workers -= [ractor]

  # Took from ractor's yield
  #if ret_val.size != NUM_REQUESTS || ret_val.any? { |val| val != RESPONSE_TEXT }
  #  raise "Wrong response from Ractor! Got #{ret_val.inspect} instead of #{RESPONSE_TEXT.inspect}!"
  #end
  #puts "Correct message received..."
#end

# Loop until all ten files exist
to_find = {}
loop do
  sleep 0.1
  10.times.select { |i| !to_find[i] }.each do |i|
    to_find[i] = true if File.exist?(idx_to_path(i))
  end
  not_yet = to_find.keys.select { |i| !File.exist?(idx_to_path(i))}.size
  break if not_yet == 0
  puts "Still looking for #{not_yet} more files..."
end

working_time = Time.now - working_t0

out_data = {
  workers: NUM_WORKERS,
  requests_per_batch: NUM_REQUESTS,
  time: working_time,
  success: true,
  pending_write_failures: [],
  pending_read_failures: [],
}
File.open(OUTFILE, "w") do |f|
  f.write JSON.pretty_generate(out_data)
end

puts "Finished..."
