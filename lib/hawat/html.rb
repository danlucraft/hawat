require 'rubyvis'

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

    def stats_time_series(output, buckets)
      output << <<-HTML
    <script type="text/javascript">
      // Load the Visualization API and the piechart package.
      google.load('visualization', '1.0', {'packages':['corechart']});
      // Set a callback to run when the Google Visualization API is loaded.
      google.setOnLoadCallback(drawChart);

      // Callback that creates and populates a data table,
      // instantiates the pie chart, passes in the data and
      // draws it.
      function drawChart() {

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
        var options = {'title':'All Frontends',
                       'width':900,
                       'height':300};

        // Instantiate and draw our chart, passing in some options.
        var chart = new google.visualization.LineChart(document.getElementById('chart_div'));
        chart.draw(data, options);
      }
    </script>
    <br><br><br><br><br><br><br>
    <div id="chart_div"></div>
        HTML
    end

    def frontends_table(fout, frontends)
      fout << "<table>"
      fout << "<tr>"
      ["Name", "Requests", "Errors", "Latency (mean)", "Latency (min)", "Latency (max)", "Max Concurrency"].each {|n| fout << "<th>#{n}</th>"}
      fout << "</tr>"
      sorted_frontends = frontends.to_a.sort_by {|_,d| d["global"]["stats"]["count"]}.reverse
      sorted_frontends.each do |name, data|
        data = data["global"]
        p data
        fout << "<tr>"
        fout << "<td>#{name}</td>"
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
      p @stats.keys
      File.open("output.html", "w") do |fout|
        fout << "<h1>Hawat</h1>"
        fout << "<h2>All</h2>"
        fout << "<script type=\"text/javascript\" src=\"https://www.google.com/jsapi\"></script>"
        <<-HTML

    <script type='text/javascript'>
      google.load('visualization', '1', {packages:['table']});
      google.setOnLoadCallback(drawTable);
      function drawTable() {
        var data = new google.visualization.DataTable();
        data.addColumn('string', 'Name');
        data.addColumn('number', 'Salary');
        data.addColumn('boolean', 'Full Time Employee');
        data.addRows([
          ['Mike',  {v: 10000, f: '$10,000'}, true],
          ['Jim',   {v:8000,   f: '$8,000'},  false],
          ['Alice', {v: 12500, f: '$12,500'}, true],
          ['Bob',   {v: 7000,  f: '$7,000'},  true]
        ]);

        var table = new google.visualization.Table(document.getElementById('table_div'));
        table.draw(data, {showRowNumber: true});
      }
    </script>
  </head>

    <div id='table_div'></div>
        HTML
        fout << "<style>#{File.read("views/style.css")}</style>"
        stats_boxes(fout, global)
        stats_time_series(fout, @stats["global_series"])
        frontends_table(fout, @stats["frontends"])
      end
    end
  end
end
