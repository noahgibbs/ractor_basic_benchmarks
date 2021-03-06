#!/usr/bin/env ruby

require 'prime'
require 'json'
require 'digest/sha1'

if ARGV.size != 3
  STDERR.puts "Usage: ./single_test <num_workers> <num_requests> <outfile>"
  exit 1
end

NUM_WORKERS = ARGV[0].to_i
NUM_REQUESTS = ARGV[1].to_i
OUTFILE = ARGV[2]

t0 = Time.now

N = NUM_REQUESTS
RN = NUM_WORKERS

out = (1..(NUM_REQUESTS*NUM_WORKERS)).map{|i|
  n = (i*100)
  bools = (n..(n+99)).map { |nn| nn.prime? }
  p_int = bools.inject(0) { |total, b| total * 2 + (b ? 1 : 0) }
  [n, p_int ]
}

t1 = Time.now
working_time = t1 - t0

out = out.sort_by {|pair| pair[0]}
out_digest = Digest::SHA1.base64digest(out.inspect)

out_data = {
  type: 'ractor',
  workers: NUM_WORKERS,
  requests: NUM_REQUESTS,
  time: working_time,
  success: true,
  digest: out_digest,
}

File.open(OUTFILE, "w") { |f| f.print(JSON.pretty_generate out_data); f.print("\n") }
puts "Successfully wrote to #{OUTFILE} w/ Digest #{out_digest.inspect}..."
