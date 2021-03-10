# Ractor Basic Benchmarking

Awhile back I [wrote some code](https://github.com/noahgibbs/fiber_basic_benchmarks/) and [some](https://appfolio-engineering.squarespace.com/appfolio-engineering/2019/9/4/benchmark-results-threads-processes-and-fibers) [articles](https://engineering.appfolio.com/appfolio-engineering/2019/10/15/more-fiber-benchmarking) on benchmarking fibers, threads and processes against each other in Ruby. The same basic approach works for Ractors - but we'll want more calculation instead of all I/O. Ractors' entire benefit is when they have to do work ***in Ruby*** rather than just C extensions or waiting for I/O.

NOTE: for released Ruby 3.0.0 I'm seeing Ractors being ***slower than threads***, which in turn means slower than single-worker. If you see the same, that doesn't mean you're doing it wrong. I started from core-team published Ractor benchmarks -- my early attempts to use the API from the basic documentation didn't go well. From this I guess that Ractors in 3.0.0 are still hard to use, and especially hard to get great performance from. I assume that "production-quality" Ractors will be a later release of Ruby.

## Using this Benchmark

For a "basic" run, just run comparison_collector.rb. After awhile, it should create a data file with the various results:

~~~
Running command: "bash -c \"ulimit -Sn 10240 && benchmarks/fork_test.rb 5 2000 /tmp/ruby_fiber_collector_1615033019_subconfig.json\""
Done, waiting for workers...
All messages delivered successfully w/ digest yDHCXpC0fKd4mE6Hp4LXl3OIpV4=...
Wrote data to file /tmp/ruby_fiber_collector_1615033019_subconfig.json.
Success...
40/40 returned success from subshell, with 0 skipped and 0 failures.
SHA1 of results: ["yDHCXpC0fKd4mE6Hp4LXl3OIpV4="]
Finished data collection, written to data/collector_data_1615033019.json
~~~

This JSON file isn't too hard to figure out, but there's also a nice utility to turn it into something easier to read. See "Analysing the Results" below.

## Changing the Settings

You can change the code of comparison_collector.rb. Up at the top it has a lot of settings:

~~~
REPS_PER_CONFIG = 10

# Try 10x messages
WORKER_CONFIGS = [
    [ 5,   2_000 ],
    #[ 10,  1_000],
    #[ 100,  10_000],
    #[ 1_000, 1_000],
]

BENCHMARKS = [
    "fork_test.rb",
    "thread_test.rb",
    "ractor_test.rb",
    "pipeless_ractor_test.rb",
]

RUBY_VERSIONS = [ "3.0.0-preview1" ]
SHELL_PREAMBLE = "ulimit -Sn 10240"
~~~

You can change the number of runs (repetitions) per configuration, and set up various different configurations (number of workers, number of messages.) Each benchmark will be run with each configuration the specified number of times.

## Analysing the Results

You can run the analyser on a JSON file of collected results to get a summary of its contents:

~~~
Noahs-MBP-2:ractor_basic_benchmarks noah$ ./analyse_coll_data.rb data/collector_data_1615033019.json
Messages-only data for configuration Pre: "ulimit -Sn 10240" Bench: "fork_test.rb" W: 5 Msg: 2000:
  samples:  10
  mean:     0.30929890000000004
  median:   0.310433
  variance: 0.0004996813500999999
  std_dev:  0.02235355341103512
-----
Whole-process data for configuration Pre: "ulimit -Sn 10240" Bench: "fork_test.rb" W: 5 Msg: 2000:
  samples:  10
  mean:     0.45333819999999997
  median:   0.439192
  variance: 0.0012912280306222245
  std_dev:  0.035933661525402956
=====
~~~

There will be a series of entries for different tests -- the output above is for "fork_test.rb". You can see the messages-only (no startup/shutdown time) vs whole-process data for a particular run, and the number of workers (5 above) and messages (2000) above the test was run with. REPS_PER_CONFIG was 10 for the run above -- or it could have been higher if there were failures. A failed run won't be counted to avoid possible sampling bias.

In general, for each configuration, the analyser will average across all repetitions.

## Credits and Contribution

I'm happy to take pull requests, but no guarantees on how promptly I'll get around to doing anything interesting with them :-)

Thanks to Marc-André Lafortune for the select-less Ractor benchmark and single-worker comparison benchmark!
