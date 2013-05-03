
class Hawat
  class Html
    def initialize(stats)
      @stats = stats
    end

    def stats_boxes(output, stats)
      output << "<div class='stats'>"
      [
        [stats["stats"]["count"], "Count"],
        [error_count(stats["stats"]["status"]), "Errors"],
        [latency(stats["stats"]["duration"]["mean"]), "Mean Latency"],
        [latency(stats["stats"]["duration"]["max"]), "Max Latency"],
        [stats["conc"]["max"], "Max Conc."]
      ].each do |value, title|
        output <<   "<div><div class='number'>#{value}</div>#{title}</div>"
      end
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
          google.setOnLoadCallback(drawChart#{@chart_i});
          function drawChart#{@chart_i}() {
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
            var options = {'title':'#{title}',
                           'width':900,
                           'height':300};
            var chart = new google.visualization.LineChart(document.getElementById('chart_div#{@chart_i}'));
            chart.draw(data, options);
          }
        </script>
        <br><br><br><br><br><br><br>
        <div id="chart_div#{@chart_i}"></div>
      HTML
    end

    def table(fout, data, sort_field: proc {|d| 1}, reach_in: proc {|d| d }, link: proc {|n| nil})
      fout << "<table>"
      fout << "<tr>"
      [
        "Name", "Requests", "Errors", "Latency (mean)", 
        "Latency (min)", "Latency (max)", "Max Concurrency"
      ].each {|n| fout << "<th>#{n}</th>"}
      fout << "</tr>"
      sorted_data = data.to_a.sort_by {|_,d| sort_field[d]}.reverse
      sorted_data.each do |name, data|
        data = reach_in[data]
        fout << "<tr>"
        l = link[name]
        if l
          fout << "<td><a onclick=\"Hawat.showDataBox('frontend-#{name}')\">#{[*name].join(" ")}</a></td>"
        else
          fout << "<td>#{[*name].join(" ")}</td>"
        end

        [
          data["stats"]["count"],
          error_count(data["stats"]["status"]),
          data["stats"]["duration"]["mean"],
          data["stats"]["duration"]["min"],
          data["stats"]["duration"]["max"],
          data["conc"]["max"]
        ].each do |cell|
          fout << "<td>#{cell}</td>"
        end
        fout << "</tr>"
      end
      fout << "</table>"
    end
    TITLE = "Hawat"

    def generate
      File.open("output.html", "w") do |fout|
        fout << "<h1><a name=top>#{TITLE}</a></h1>"
        fout << "<script type=\"text/javascript\" src=\"https://www.google.com/jsapi\"></script>"
        fout << "<script src=\"http://ajax.googleapis.com/ajax/libs/jquery/1.9.0/jquery.min.js\" type=\"text/javascript\"></script>"
        fout << "<script>#{File.read("views/js.js")}</script>"
        fout << "<style>#{File.read("views/style.css")}</style>"
        fout << "<div id=container>"

        fout << "<div class=databox id=global>"
        fout << "<div id=breadcrumbs><h2>All</h2></div>"
        stats_boxes(fout, @stats["global"]["all"])
        stats_time_series(fout, "All frontends", @stats["global"]["series"])

        table(fout, @stats["frontends"], 
              sort_field: proc {|d| d["global"]["all"]["stats"]["count"]}, 
              reach_in: proc {|d| d["global"]["all"] },
              link: proc {|n| "frontend-#{n}" })
        fout << "</div>"

        @stats["frontends"].each do |name, data|
          fout << "<div class=databox id=\"frontend-#{name}\" style=\"display:none;\">"
          fout << ""
          fout << "<div id=breadcrumbs><h2><a onclick=\"Hawat.showDataBox('global')\">top</a> &gt; #{name}</h2></div>"
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
      end
    end

  end
end
