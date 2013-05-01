
class Hawat
  def initialize(log_path)
    @log_path = log_path
  end

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

  class Aggregate
    def initialize
      @stats = Statistics.new
      @conc = Concurrency.new
    end

    def update(line)
      @stats.update(line)
      @conc.update(line)
    end
    
    def result
      {
        "stats" => @stats.result,
        "concurrency" => @conc.result
      }
    end
  end

  class TimeBucketer
    def initialize(bucket_length_in_seconds, &block)
      @bucket_length = bucket_length_in_seconds
      @buckets = []
      @aggregate_generator = block
    end

    class Bucket < Struct.new(:start, :finish, :aggregate)
    end

    def update(line)
      close = line.closed
      @beginning_of_day ||= Time.local(close.year, close.mon, close.day, 0, 0, 0)
      close_s = close.to_i
      close_s_today = close_s - @beginning_of_day.to_i
      bucket_i = close_s_today/@bucket_length
      @buckets[bucket_i] ||= Bucket.new(@beginning_of_day + bucket_i*@bucket_length,
                                        @beginning_of_day + bucket_i*@bucket_length,
                                        @aggregate_generator.call)
      @buckets[bucket_i].aggregate.update(line)
    end

    def result
      h = {}
      @buckets.each do |b|
        if b
          h[b.start] = b.aggregate.result
        end
      end
      h
    end
  end

  class Statistics
    attr_reader :count, :total_duration, :max_duration, :min_duration, :statuses

    def initialize
      @count          = 0
      @total_duration = 0
      @max_duration   = 0
      @min_duration   = 100000000
      @statuses       = Hash.new {|h,k| h[k] = 0}
    end

    def update(line_data)
      @count += 1
      dur = line_data.total_time
      @total_duration += dur
      @max_duration = dur if dur > @max_duration
      @min_duration = dur if dur < @min_duration
      @statuses[line_data.status] += 1
    end

    def merge(other)
      @count          += other.count
      @total_duration += other.total_duration
      @statuses        = @statuses.merge(other.statuses)

      @max_duration = other.max_duration if other.max_duration > @max_duration
      @min_duration = other.min_duration if other.min_duration < @min_duration
    end

    def result
      if @count == 0
        {
          "count" => 0,
        }
      else
        {
          "count" => @count,
          "status" => @statuses,
          "duration" => {
            "min"  => @min_duration,
            "mean" => (@total_duration.to_f/@count).to_i,
            "max"  => @max_duration
          }
        }
      end
    end
  end

  class PathStats
    class Node
      attr_reader :count, :children, :terminal

      def initialize(terminal_generator)
        @children = {}
        @count = 0
        @terminal_generator = terminal_generator
        @terminal = terminal_generator[]
      end

      def add(path, line)
        @count += 1
        @terminal.update(line)
        bits = path.split("/")
        if bits.length > 1
          name = bits[1]
          node = (@children[name] ||= Node.new(@terminal_generator))
          node.add("/" + bits[2..-1].join("/"), line)
        end
      end

      def reduce
        #new_children = {"*" => Node.new(@terminal_generator) }
        #@children.each do |slug, node|
          #if node.count < @count/19
            #new_children["*"].merge(node)
          #else
            #new_children[slug] = node
          #end
        #end
        #unless new_children["*"].count > 0
          #new_children.delete("*")
        #end
        #@children = new_children
        
        if @children.length > 15
          new_children = {"*" => Node.new(@terminal_generator) }
          @children.each do |slug, node|
            new_children["*"].merge(node)
          end
          @children = new_children
        end

        @children.each {|slug, node| node.reduce }
      end

      def merge(other)
        @count += other.count
        other.children.each do |slug, node|
          @children[slug] ||= node
          @children[slug].merge(node)
        end
        @terminal.merge(other.terminal)
      end

      def inspect(indent=0, s="")
        @children.each do |slug, node|
          s << " "*indent + "/#{slug} (#{node.count})\n"
          node.inspect(indent + 2, s)
        end
        s
      end

      def collect(path, out)
        @children.each do |slug, node|
          node.collect(path + "/" + slug, out)
        end
        out[path] = terminal.result
      end
    end

    def initialize(&terminal_generator)
      @nodes = {}
      @terminal_generator = terminal_generator
    end

    def update(line)
      node = (@nodes[line.http_method] ||= Node.new(@terminal_generator))
      node.add(line.path.split("?").first, line)
    end

    def result
      @nodes.values.each {|node| node.children.each {|slug, node| node.reduce } }
      result = {}
      @nodes.each do |method, node|
        r = {}
        node.collect("", r)
        result[method] = r
      end
      result
    end

  end

  class Concurrency
    def initialize
      @max_concurrency = 0
      @live_requests = []
    end

    def update(line)
      acc_s = line.accepted.to_r
      close_s = line.closed.to_r
      @live_requests.reject! {|l| l > close_s }
      @live_requests << acc_s
      conc = @live_requests.length
      if conc > @max_concurrency
        @max_concurrency = conc 
      end
    end

    def result
      {
        "max" => @max_concurrency
      }
    end
  end

  class FrontendStatistics
    def initialize
      @stats = Hash.new {|h,k| h[k] = yield }
      @path_stats = Hash.new { |h,k| h[k] = PathStats.new { Statistics.new } }
    end

    def update(line_data)
      @stats[line_data.frontend].update(line_data)
      @path_stats[line_data.frontend].update(line_data)
    end

    def result
      h = {}
      @stats.each do |key, agg|
        h[key] ||= {}
        h[key]["stats"] = agg.result
      end
      @path_stats.each do |key, agg|
        h[key] ||= {}
        h[key]["pathStats"] = agg.result
      end
      h
    end
  end

  def default_stats
    [
      NamedAggregate.new("global", Aggregate.new),
      NamedAggregate.new("global_series", TimeBucketer.new(5) { Aggregate.new }),
      NamedAggregate.new("frontends", FrontendStatistics.new { Aggregate.new })
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

  # example 
  # Apr 28 00:00:15 dc1-live-lb1.srv.songkick.net haproxy[32647]: 10.32.75.139:53757 [28/Apr/2013:00:00:15.885] skweb skweb/dc1-live-frontend6_3000 0/0/9/9/20 200 5732 - - ---- 104/39/39/5/0 0/0 \"GET /favicon.ico HTTP/1.1\"\n"
  LINE_RE = /^(\w+ \d+ \d+:\d+:\d+) (\S+) haproxy\[(\d+)\]: ([\d\.]+):(\d+) \[(\d+)\/(\w+)\/(\d+):(\d+:\d+:\d+\.\d+)\] ([^ ]+) ([^ ]+)\/([^ ]+) (-?\d+)\/(-?\d+)\/(-?\d+)\/(-?\d+)\/(-?\d+) (\d+) (\d+) - - ([\w-]+) (-?\d+)\/(-?\d+)\/(-?\d+)\/(-?\d+)\/(-?\d+) (\d+)\/(\d+) "(\w+) ([^ ]+)/

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

    def accepted
      hour, minute, sec, milli = *timestamp.split(/:|\./)
      Time.local(year.to_i, month, day.to_i, hour.to_i, minute.to_i, sec.to_i, milli.to_i*1000)
    end

    def closed
      dur_s = Rational(total_time, 1000)
      Time.at(accepted.to_r + dur_s)
    end

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

