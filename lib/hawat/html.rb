
class Hawat
  class Html
    def initialize(stats)
      @stats = stats
    end

    def global
      @stats["global"]
    end

    def stats_boxes(output, stats)
      output << "<div class='stats'>"
      output <<   "<div><div class='number'>#{stats["stats"]["count"]}</div>Count</div>"
      output <<   "<div><div class='number'>#{error_count(stats["stats"]["status"])}</div>Errors</div>"
      output <<   "<div><div class='number'>#{latency(stats["stats"]["duration"]["mean"])}</div>Mean Latency</div>"
      output <<   "<div><div class='number'>#{latency(stats["stats"]["duration"]["max"])}</div>Max Latency</div>"
      output <<   "<div><div class='number'>#{stats["conc"]["max"]}</div>Max Conc</div>"
      output << "</div>"
    end

    def error_count(status_counts)
      status_counts.inject(0) {|m,(s,c)| (s !~ /^2/ && s != "404") ? m + c : m }
    end

    def latency(value_ms)
      if value_ms > 1000
        "%5.1f<span class='units'>s</span>" % (value_ms.to_f/1000)
      else
        "#{value_ms}<span class='units'>ms</span>"
      end
    end

    def stats_time_series(output, title, buckets)
      @chart_i ||= 0
      @chart_i += 1
      output << <<-HTML
    <script type="text/javascript">
      // Set a callback to run when the Google Visualization API is loaded.
      google.setOnLoadCallback(drawChart#{@chart_i});

      // Callback that creates and populates a data table,
      // instantiates the pie chart, passes in the data and
      // draws it.
      function drawChart#{@chart_i}() {

        // Create the data table.
        var data = new google.visualization.DataTable();
        data.addColumn('string', 'Time');
        data.addColumn('number', 'Requests');
        data.addRows([
      HTML
      buckets.each do |time, stats|
        output << "['#{time}', #{stats["stats"]["count"]}],"
      end
      output << <<-HTML
        ]);

        // Set chart options
        var options = {'title':'#{title}',
                       'width':900,
                       'height':300};

        // Instantiate and draw our chart, passing in some options.
        var chart = new google.visualization.LineChart(document.getElementById('chart_div#{@chart_i}'));
        chart.draw(data, options);
      }
    </script>
    <br><br><br><br><br><br><br>
    <div id="chart_div#{@chart_i}"></div>
        HTML
    end

    def table(fout, data, sort_field: proc {|d| 1}, reach_in: proc {|d| d })
      fout << "<table>"
      fout << "<tr>"
      ["Name", "Requests", "Errors", "Latency (mean)", "Latency (min)", "Latency (max)", "Max Concurrency"].each {|n| fout << "<th>#{n}</th>"}
      fout << "</tr>"
      sorted_data = data.to_a.sort_by {|_,d| sort_field[d]}.reverse
      sorted_data.each do |name, data|
        data = reach_in[data]
        fout << "<tr>"
        fout << "<td>#{[*name].join(" ")}</td>"
        fout << "<td>#{data["stats"]["count"]}</td>"
        fout << "<td>#{error_count(data["stats"]["status"])}</td>"
        fout << "<td>#{data["stats"]["duration"]["mean"]}</td>"
        fout << "<td>#{data["stats"]["duration"]["min"]}</td>"
        fout << "<td>#{data["stats"]["duration"]["max"]}</td>"
        fout << "<td>#{data["conc"]["max"]}</td>"
        fout << "</tr>"
      end
      fout << "</table>"
    end

    def generate
      File.open("output.html", "w") do |fout|
        fout << "<h1>Hawat</h1>"
        fout << "<script type=\"text/javascript\" src=\"https://www.google.com/jsapi\"></script>"
        fout << "<script>#{File.read("views/js.js")}</script>"
        fout << "<style>#{File.read("views/style.css")}</style>"
        fout << "<div id=container>"

        fout << "<div id=global>"
        fout << "<div id=breadcrumbs><h2>All</h2></div>"
        stats_boxes(fout, @stats["global"]["all"])
        stats_time_series(fout, "All frontends", @stats["global"]["series"])

        table(fout, @stats["frontends"], 
              sort_field: proc {|d| d["global"]["all"]["stats"]["count"]}, 
              reach_in: proc {|d| d["global"]["all"] })
        fout << "</div>"

        @stats["frontends"].each do |name, data|
          fout << "<div id=\"frontend-#{name}\">"
          fout << "<div id=breadcrumbs><h2>#{name}</h2></div>"
          stats_boxes(fout, data["global"]["all"])
          stats_time_series(fout, name, data["global"]["series"])
          new_data = {}
          data["paths"].each do |path, methods|
            methods.each do |method, data|
              new_data[[method, path]] = data
            end
          end
          table(fout, new_data,
                sort_field: proc {|d| d["all"]["stats"]["count"] },
                reach_in: proc {|d| d["all"] })
          fout << "</div>"
        end
        fout << "</div>"
      end
    end

  end
end
