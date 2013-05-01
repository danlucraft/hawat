
class Hawat
  class Html
    def initialize(stats)
      @stats = stats
    end

    def global
      @stats["global"]
    end

    def stats_boxes(output, stats)
      p stats
      output << "<div class='stats'>"
      output <<   "<div><div class='number'>#{stats["count"]}</div>Count</div>"
      error_count = stats["status"].inject(0) {|m,(s,c)| (s !~ /^2/ && s != "404") ? m + c : m }
      output <<   "<div><div class='number'>#{error_count}</div>Errors</div>"
      output <<   "<div><div class='number'>#{latency(stats["duration"]["mean"])}</div>Mean Latency</div>"
      output <<   "<div><div class='number'>#{latency(stats["duration"]["max"])}</div>Max Latency</div>"
      output << "</div>"
    end

    def latency(value_ms)
      if value_ms > 1000
        "%5.1f<span class='units'>s</span>" % (value_ms.to_f/1000)
      else
        "#{value_ms}<span class='units'>ms</span>"
      end
    end

    def generate
      File.open("output.html", "w") do |fout|
        fout << "<h1>All</h1>"
        fout << "<style>#{File.read("views/style.css")}</style>"
        stats_boxes(fout, global["stats"])
      end
    end
  end
end
