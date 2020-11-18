#!/usr/bin/env ruby

require 'prime'
require 'json'
require 'digest/sha1'

if ARGV.size != 3
  STDERR.puts "Usage: ./thread_test <num_workers> <num_requests> <outfile>"
  exit 1
end

NUM_WORKERS = ARGV[0].to_i
NUM_REQUESTS = ARGV[1].to_i
OUTFILE = ARGV[2]

# Create a singleton work queue to take work from
class WorkQueue
  attr_reader :results
  attr_reader :work

  def initialize(work)
    @work = work
    @mutex = Mutex.new
    @results = []
  end

  # Take a piece of work
  def take
    work = nil
    @mutex.synchronize do
      work = @work.pop
    end
    work
  end

  # Return the results
  def give(res)
    @mutex.synchronize do
      @results.push(res)
    end
  end
end

t0 = Time.now

WQ = WorkQueue.new (1..(NUM_REQUESTS*NUM_WORKERS)).map { |x| x * 100 }

workers = (1..NUM_WORKERS).map do
  Thread.new do
    loop do
      item = WQ.take
      break if item.nil?
      bools = (item..(item+99)).map { |nn| nn.prime? }
      p_int = bools.inject(0) { |total, b| total * 2 + (b ? 1 : 0) }
      WQ.give [item, p_int]
    end
  end
end

sleep 0.05 until WQ.work.empty?
sleep 0.05 until WQ.results.size == NUM_REQUESTS * NUM_WORKERS
t1 = Time.now
working_time = t1 - t0

out = WQ.results
out.sort_by! {|pair| pair[0]}
out_digest = Digest::SHA1.base64digest(out.inspect)

out_data = {
  type: 'thread',
  workers: NUM_WORKERS,
  requests: NUM_REQUESTS,
  time: working_time,
  success: true,
  digest: out_digest,
}

File.open(OUTFILE, "w") { |f| f.print(JSON.pretty_generate out_data); f.print("\n") }
puts "Successfully wrote to #{OUTFILE} w/ Digest #{out_digest.inspect}..."
