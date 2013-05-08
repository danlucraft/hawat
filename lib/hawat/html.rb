
class Hawat
  class Html
    def initialize(stats)
      @stats = stats
    end

    def stats_boxes(output, stats)
      output << "<div class='stats'>"
      chart_ids = []
      @boxes_id ||= 0
      [
        [stats["stats"]["count"],                     "Count"],
        [error_count(stats["stats"]["status"]),       "Errors"],
        [latency(stats["stats"]["duration"]["mean"]), "Mean Latency"],
        [latency(stats["stats"]["duration"]["max"]),  "Max Latency"],
        [stats["conc"]["max"],                        "Max Conc."]
      ].each do |value, title|
        @boxes_id += 1
        chart_id = title.gsub(" ", "-").downcase.gsub(/[^a-z0-9]/, "") + @boxes_id.to_s
        output <<  "<div><a onclick=\"Hawat.displayChart('#{chart_id}')\"><div class='number'>#{value}</div>#{title}</a></div>\n"
        chart_ids << chart_id
      end
      output << "</div>"
      chart_ids
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

    def stats_time_series(output, title, buckets, reach_in: proc {|d| d}, chart_id: nil, display: false)
      @chart_i ||= 0
      chart_id ||= (@chart_i += 1)
      output << <<-HTML
        <script type="text/javascript">
          Hawat.drawChart#{chart_id} = function() {
            console.log("drawChart#{chart_id}()")
            var data = new google.visualization.DataTable();
            data.addColumn('string', 'Time');
            data.addColumn('number', 'Requests');
            data.addRows([
          HTML
          buckets.each do |time, stats|
            output << "['#{time}', #{reach_in[stats]}],"
          end
          output << <<-HTML
            ]);
            var options = {'title':'#{title}',
                           'width':900,
                           'height':300};
            var chart = new google.visualization.LineChart(document.getElementById('chart-#{chart_id}'));
            chart.draw(data, options);
          }
        </script>
        <div style="#{display ? "" : "display:none;"}clear:both;" id="chart-#{chart_id}" class="chart" data-function="drawChart#{chart_id}"></div>
      HTML
      "drawChart#{chart_id}"
    end

    def table(fout, data, sort_field: proc {|d| 1}, reach_in: proc {|d| d }, link: proc {|n,i| nil})
      fout << "<table>\n"
      fout << "<tr>"
      [
        "Name", "Requests", "Errors", "Latency (mean)", 
        "Latency (min)", "Latency (max)", "Max Concurrency"
      ].each {|n| fout << "<th>#{n}</th>"}
      fout << "</tr>\n"
      sorted_data = data.to_a.sort_by {|_,d| sort_field[d]}.reverse
      sorted_data.each_with_index do |(name, data), i|
        data = reach_in[data]
        fout << "<tr>"
        l = link[name,i]
        if l
          fout << (s="<td><a onclick=\"Hawat.showDataBox('#{l}')\">#{[*name].join(" ")}</a></td>")
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
        fout << "</tr>\n"
      end
      fout << "</table>\n"
    end
    TITLE = "Hawat"

    def boxes(fout, title, data, display: false)
      chart_ids = stats_boxes(fout, data["all"])
      ids = chart_ids.clone
      first = true
      [
        ["Requests",        proc {|d| d["stats"]["count"] },             ],
        ["Errors",          proc {|d| error_count(d["stats"]["status"]) }],
        ["Mean Latency",    proc {|d| d["stats"]["duration"]["mean"] }   ],
        ["Max Latency",     proc {|d| d["stats"]["duration"]["max"] }    ],
        ["Max Concurrency", proc {|d| d["conc"]["max"] }                 ],
      ].each do |sub_title, fetch|
        id = stats_time_series(fout, "#{title} #{sub_title}", data["series"], reach_in: fetch, chart_id: ids.shift, display: first)
        first = false
        if display
          fout << "<script>Hawat.#{id}()</script>"
        end
      end
      chart_ids
    end

    def generate
      File.open("output.html", "w") do |fout|
        fout << "<h1><a name=top>#{TITLE}</a></h1>\n"
        fout << "<script type=\"text/javascript\" src=\"https://www.google.com/jsapi\"></script>\n"
        fout << "<script src=\"http://ajax.googleapis.com/ajax/libs/jquery/1.9.0/jquery.min.js\" type=\"text/javascript\"></script>\n"
        fout << "<script>#{File.read("views/js.js")}</script>\n"
        fout << "<style>#{File.read("views/style.css")}</style>\n"
        fout << "<div id=container>\n"

        fout << "<div class=databox id=global>\n"
        fout << "<div id=breadcrumbs><h2>All</h2></div>\n"
        chart_ids = boxes(fout, "All frontends", @stats["global"], display: true)
        #fout <<  "<script>$(document).ready(function() { Hawat.displayChart('#{chart_ids.first}') })</script>\n"
        table(fout, @stats["frontends"], 
              sort_field: proc {|d| d["global"]["all"]["stats"]["count"]}, 
              reach_in: proc {|d| d["global"]["all"] },
              link: proc {|n,i| "frontend-#{n}" })
        fout << "</div>"

        @stats["frontends"].each do |name, data|
          fout << "<div class=databox id=\"frontend-#{name}\" style=\"display:none;\">\n"
          fout << "\n"
          fout << "<div id=breadcrumbs><h2><a onclick=\"Hawat.showDataBox('global')\">top</a> &gt; #{name}</h2></div>\n"
          boxes(fout, name, data["global"], display: false)
          new_data = {}
          data["paths"].each do |path, methods|
            methods.each do |method, data|
              new_data[[method, path]] = data
            end
          end
          table(fout, new_data,
                sort_field: proc {|d| d["all"]["stats"]["count"] },
                reach_in: proc {|d| d["all"] },
                link: proc {|n,i| "frontend-#{name}-path-#{i}" })
          fout << "</div>"

          path_id = 0
          new_data.each do |(method, path), path_data|
            path_id += 1
            next if path_id > 2
            fout << "<div class=databox id=\"frontend-#{name}-path-#{path_id}\" style=\"display:none;\">\n"
            boxes(fout, "#{name}, #{method} #{path}", path_data, display: false)
            fout << "</div>"
          end
        end
      end
    end

  end
end


