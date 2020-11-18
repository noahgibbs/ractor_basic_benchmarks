#!/usr/bin/env ruby

# This script runs the various benchmarks and collects data from them.

# Each configuration is a number of workers and a number of requests per batch.
# A worker (thread, process, ractor) will run for one batch and then terminate. So small batches test
# worker startup/shutdown time, while larger batches test the time to hand off a message between
# different concurrency setups - threads and fibers might well have an advantage over
# processes for message I/O efficiency, for instance.

REPS_PER_CONFIG = 1

# Try 10x messages
WORKER_CONFIGS = [
    [ 5,   10],
    #[ 10,  1_000],
    #[ 100,  10_000],
    #[ 1_000, 1_000],
]

BENCHMARKS = [
    "fork_test.rb",
    "thread_test.rb",
    "ractor_test.rb",
]

RUBY_VERSIONS = [ "3.0.0-preview1" ]
SHELL_PREAMBLE = "ulimit -Sn 10240"

COLLECTOR_TS = Time.now.to_i

require "json"

data_filename = "collector_data_#{COLLECTOR_TS}.json"
out_data = {
    collector_ruby_version: RUBY_VERSION,
    reps_per_config: REPS_PER_CONFIG,
    configs: WORKER_CONFIGS,
    benchmarks: BENCHMARKS,
    preamble: SHELL_PREAMBLE,
    summary: {},
    results: [],
}

# Generate all configurations
configs_w_preamble =
(0...REPS_PER_CONFIG).flat_map { |rep|
      BENCHMARKS.flat_map { |bench|
          WORKER_CONFIGS.map { |c| [rep, SHELL_PREAMBLE, bench] + c }
      }
}

#puts "All configs:\n#{JSON.pretty_generate configs_w_preamble}"

# Randomize the order of trials
ordered_configs = configs_w_preamble.sample(configs_w_preamble.size)

successes = 0
failures = 0
skips = 0
no_data = 0

run_data_file = "/tmp/ruby_fiber_collector_#{COLLECTOR_TS}_subconfig.json"

ordered_configs.each do |config|
  rep_num, preamble, bench, workers, messages = *config

  File.unlink(run_data_file) if File.exist?(run_data_file)
  shell_command = "bash -c \"#{preamble} && benchmarks/#{bench} #{workers} #{messages} #{run_data_file}\""
  shell_t0 = Time.now
  #puts "Running with config: #{rep_num.inspect} #{preamble.inspect} #{bench.inspect} #{workers.inspect} #{messages.inspect}..."
  puts "Running command: #{shell_command.inspect}"
  result = system(shell_command)
  shell_tfinal = Time.now
  shell_elapsed = shell_tfinal - shell_t0

  data_present = File.exist? run_data_file
  run_data = {
      rep_num: rep_num,
      preamble: preamble,
      benchmark: bench,
      workers: workers,
      messages: messages,
      result_status: result,
      whole_process_time: shell_elapsed,
  }

  if result && data_present
    puts "Success..."
    successes += 1
  elsif result
    puts "Success with no data..."
    no_data += 1
  elsif data_present
    puts "This really shouldn't happen! Outfile: #{run_data_file}"
    raise "Data file written but subprocess failed!"
  else
    puts "Failure..."
    failures += 1
  end

  run_data[:result_data] = nil
  run_data[:result_data] = JSON.load(File.read run_data_file) if data_present
  run_data[:digest] = run_data[:result_data]["digest"] if data_present

  out_data[:results].push run_data
end

if ordered_configs.size != successes + failures + skips + no_data
    puts "Error in collector bookkeeping! #{ordered_configs.size} total configurations, but: successes: #{successes}, failures: #{failures}, no data: #{no_data}, skips: #{skips}"
end

out_data[:summary] = {
    successes: successes,
    failures: failures,
    skips: skips,
    no_data: no_data,
    total_configs: ordered_configs.size,
    digests: out_data[:results].map { |r| r[:digest] }.compact.uniq
}

File.open(data_filename, "w") do |f|
    f.write JSON.pretty_generate(out_data)
end
puts "#{successes}/#{successes + failures + skips} returned success from subshell, with #{skips} skipped and #{failures} failures."
puts "SHA1 of results: #{out_data[:summary][:digests].inspect}"
puts "ERROR: MORE THAN ONE DIGEST RESULT!" if out_data[:summary][:digests].size != 1
puts "Finished data collection, written to #{data_filename}"
