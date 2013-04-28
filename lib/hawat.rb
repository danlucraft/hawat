
class Hawat
  def initialize(log_path)
    @log_path = log_path
  end

  # example 
  # Apr 28 00:00:15 dc1-live-lb1.srv.songkick.net haproxy[32647]: 10.32.75.139:53757 [28/Apr/2013:00:00:15.885] skweb skweb/dc1-live-frontend6_3000 0/0/9/9/20 200 5732 - - ---- 104/39/39/5/0 0/0 \"GET /favicon.ico HTTP/1.1\"\n"
  LINE_RE = /^(\w+ \d+ \d+:\d+:\d+) (\S+) haproxy\[(\d+)\]: ([\d\.]+):(\d+) \[(\d+)\/(\w+)\/(\d+):(\d+:\d+:\d+\.\d+)\] ([^ ]+) ([^ ]+)\/([^ ]+) (-?\d+)\/(-?\d+)\/(-?\d+)\/(-?\d+)\/(-?\d+) (\d+) (\d+) - - ([\w-]+) (-?\d+)\/(-?\d+)\/(-?\d+)\/(-?\d+)\/(-?\d+) (\d+)\/(\d+) "(\w+) ([^ ]+)/

  class NamedAggregate
    def initialize(name, aggregate)
      @name, @aggregate = name, aggregate
    end
  
    def update(line)
      @aggregate.update(line)
    end
    
    def result
      {@name => @aggregate.result}
    end
  end

  class AggregateStatistics
    def initialize
      @count = 0
      @duration = 0
    end

    def update(line_data)
      @count += 1
      @duration += line_data.total_time
    end

    def result
      {
        "count"         => @count,
        "duration_mean" => (@duration.to_f/@count).to_i
      }
    end
  end

  class AggregateCollection < Hash
    def initialize
      super
      self.default_proc = lambda {|h,k| h[k] = AggregateStatistics.new }
    end

    def result
      h = {}
      each do |key, agg|
        h[key] = agg.result
      end
      h
    end

  end

  class FrontendStatistics
    def initialize
      @stats = AggregateCollection.new
    end

    def update(line_data)
      @stats[line_data.frontend].update(line_data)
    end

    def result
      {"frontends" => @stats.result}
    end
  end

  def default_stats
    [
      NamedAggregate.new("global", AggregateStatistics.new),
      FrontendStatistics.new
    ]
  end

  def each_line
    line_data = LineData.new
    File.open(@log_path) do |file|
      while line = file.gets
        if md = LINE_RE.match(line)
          line_data.md = md
          yield line_data
        else
          $stderr.puts "LINE DIDN'T MATCH: #{line}"
        end
      end
    end
  end

  def statistics
    stats = default_stats
    each_line do |line|
      stats.each {|s| s.update(line) }
    end
    stats.map(&:result).inject(&:merge)
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
    def tq; md[13].to_i; end
    def tw; md[14].to_i; end
    def tc; md[15].to_i; end
    def tr; md[16].to_i; end
    def total_time; md[17].to_i; end
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

