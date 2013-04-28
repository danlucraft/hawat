
class Hawat
  def initialize(log_path)
    @log_path = log_path
  end

  # example 
  # Apr 28 00:00:15 dc1-live-lb1.srv.songkick.net haproxy[32647]: 10.32.75.139:53757 [28/Apr/2013:00:00:15.885] skweb skweb/dc1-live-frontend6_3000 0/0/9/9/20 200 5732 - - ---- 104/39/39/5/0 0/0 \"GET /favicon.ico HTTP/1.1\"\n"
  LINE_RE = /^(\w+ \d+ \d+:\d+:\d+) (\S+) haproxy\[(\d+)\]: ([\d\.]+):(\d+) \[(\d+)\/(\w+)\/(\d+):(\d+:\d+:\d+\.\d+)\] ([^ ]+) ([^ ]+)\/([^ ]+) (-?\d+)\/(-?\d+)\/(-?\d+)\/(-?\d+)\/(-?\d+) (\d+) (\d+) - - ([\w-]+) (-?\d+)\/(-?\d+)\/(-?\d+)\/(-?\d+)\/(-?\d+) (\d+)\/(\d+) "(\w+) ([^ ]+)/

  def statistics
    count = 0
    line_data = LineData.new
    File.open(@log_path) do |file|
      while line = file.gets
        count += 1
        if md = LINE_RE.match(line)
          line_data.md = md
        else
          $stderr.puts "LINE DIDN'T MATCH: #{line}"
        end
      end
    end
    {:requests => count}
  end

  class LineData
    attr_accessor :md

    def haproxy_host; md[2]; end
    def haproxy_pid;  md[3]; end
    def haproxy_ip;  md[4]; end
    def haproxy_port;  md[5]; end
    def day;           md[6]; end
    def month; md[7]; end
    def year; md[8]; end
    def timestamp; md[9]; end
    def frontend; md[10]; end
    def backend; md[11]; end
    def server; md[12]; end
    def tq; md[13]; end
    def tw; md[14]; end
    def tc; md[15]; end
    def tr; md[16]; end
    def tt; md[17]; end
    def status; md[18]; end
    def bytes; md[19]; end
    def termination_state; md[20]; end
    def actconn; md[21]; end
    def feconn; md[22]; end
    def beconn; md[23]; end
    def srv_conn; md[24]; end
    def retries; md[25]; end
    def srv_queue; md[26]; end
    def backend_queue; md[27]; end
    def http_method; md[28]; end
    def path; md[29]; end
  end
end
