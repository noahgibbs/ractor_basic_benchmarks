#!/usr/bin/env ruby

require 'socket'
require 'json'
require 'prime'
require 'digest/sha1'

if ARGV.size != 3
  STDERR.puts "Usage: ./fork_test <num_workers> <num_requests> <outfile>"
  exit 1
end

NUM_WORKERS = ARGV[0].to_i
NUM_REQUESTS = ARGV[1].to_i
OUTFILE = ARGV[2]

OUT_SIZE = 50

if NUM_REQUESTS >= 100_000_000
  raise "Due to a silly protocol limit, your number of requests must be less than 100 million."
end

worker_read = []
worker_write = []

master_read = []
master_write = []

writable_idx_for = {}
readable_idx_for = {}

workers = []

#puts "Setting up pipes..."
working_t0 = Time.now
NUM_WORKERS.times do |i|
  r, w = IO.pipe
  worker_read.push r
  master_write.push w
  writable_idx_for[w] = i

  r, w = IO.pipe
  worker_write.push w
  master_read.push r
  readable_idx_for[r] = i
end

#puts "Setting up processes..."
NUM_WORKERS.times do |i|
  pid = fork do
    # Worker code
    NUM_REQUESTS.times do |req_num|
      n = worker_read[i].read(8).to_i * 100  # Read eight bytes, convert to int

      bools = (n..(n+99)).map { |nn| nn.prime? }
      p_int = bools.inject(0) { |total, b| total * 2 + (b ? 1 : 0) }
      #puts "Finished work for req_num #{n} in worker #{i}."
      res = "#{n},#{p_int}"
      resp = " " * (OUT_SIZE - res.size) + res
      raise "Wrong response size #{resp.size} instead of #{OUT_SIZE}!" unless resp.size == OUT_SIZE
      worker_write[i].print(resp)
    end
  end
  workers.push pid
end

### Master code ###

pending_write_msgs = (1..NUM_WORKERS).map { NUM_REQUESTS }
pending_read_msgs = pending_write_msgs.dup
out_pairs = []

#puts "Starting master..."
req_index = 0
loop do
  break if master_read.empty? && master_write.empty?
  readable, writable = IO.select master_read, master_write, []

  # Receive responses
  readable.each do |io|
    idx = readable_idx_for[io]

    buf = io.read(OUT_SIZE)
    #STDERR.puts "Received work receipt for worker #{idx}: #{buf.inspect}"
    out_pairs << buf.split(",", 2).map(&:to_i)

    pending_read_msgs[idx] -= 1
    if pending_read_msgs[idx] == 0
      # This changes the indexing of master_read, so it
      # must never be indexed by number. But we don't want
      # to keep seeing it as readable on every select call...
      #puts "Last read from worker ##{idx}... Removing it."
      master_read.delete(io)
    end
  end

  # Send new messages
  writable.each do |io|
    idx = writable_idx_for[io]
    req_index += 1
    io.print ("%08d" % req_index)  # The request number, padded to 8 total bytes
    pending_write_msgs[idx] -= 1
    if pending_write_msgs[idx] == 0
      # This changes the indexing of master_write, so it
      # must never be indexed by number. But we don't want
      # to keep seeing it as writable on every select call...
      #puts "Last write to worker ##{idx}... Removing it."
      master_write.delete(io)
    end
  end
end

puts "Done, waiting for workers..."
working_time = Time.now - working_t0
workers.each { |pid| Process.waitpid(pid) }

out_pairs.sort_by! { |p| p[0] }
out_digest = Digest::SHA1.base64digest(out_pairs.inspect)
pp out_pairs

success = true
if pending_write_msgs.any? { |p| p != 0 } || pending_read_msgs.any? { |p| p != 0}
  puts "Not all messages were delivered!"
  puts "Remaining read: #{pending_read_msgs.inspect}"
  puts "Remaining write: #{pending_write_msgs.inspect}"
  success = false
else
  puts "All messages delivered successfully w/ digest #{out_digest}..."
end

out_data = {
  workers: NUM_WORKERS,
  requests_per_batch: NUM_REQUESTS,
  time: working_time,
  success: success,
  pending_write_failures: pending_write_msgs.select { |n| n != 0 },
  pending_read_failures: pending_read_msgs.select { |n| n != 0 },
  digest: out_digest,
}
File.open(OUTFILE, "w") do |f|
  f.write JSON.pretty_generate(out_data)
end
puts "Wrote data to file #{OUTFILE}."
# Exit
