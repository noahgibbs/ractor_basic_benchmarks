#!/usr/bin/env ruby

require 'socket'
server = TCPServer.new(8080)
CPU_COUNT = 4
workers = CPU_COUNT.times.map do
  Ractor.new do
    loop do
      # receive TCPSocket
      s = Ractor.recv

      request = s.gets
      puts request

      s.print "HTTP/1.1 200\r\n"
      s.print "Content-Type: text/html\r\n"
      s.print "\r\n"
      s.print "Hello world! The time is #{Time.now}\n"
      s.close
    end
  end
end

loop do
  conn, _ = server.accept
  # pass TCPSocket to one of the workers
  workers.sample.send(conn, move: true)
end
