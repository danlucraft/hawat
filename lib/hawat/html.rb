require 'andand'

class Hawat
  class Html
    def initialize(stats)
      @stats = stats
    end

    def boxes(title, data)
      result = {
        "boxes" => stats_boxes(data["all"]),
        "charts" => {}
      }
      [
        ["requests",      "Requests",        proc {|d| d["stats"]["count"] },             ],
        ["errors",        "Errors",          proc {|d| error_count(d["stats"]["status"]) }],
        ["mean-duration", "Mean Latency",    proc {|d| d["stats"]["duration"]["mean"] }   ],
        ["max-duration",  "Max Latency",     proc {|d| d["stats"]["duration"]["max"] }    ],
        ["max-conc",      "Max Concurrency", proc {|d| d["conc"].andand["max"] }                 ],
      ].each do |bind, sub_title, fetch|
        result["charts"][bind] = stats_time_series("#{title} #{sub_title}", data["series"], reach_in: fetch)
      end
      result
    end

    def stats_boxes(stats)
      result = []
      [
        [stats["stats"]["count"],                "bigstat-requests", ""],
        [error_count(stats["stats"]["status"]),  "bigstat-errors", ""],
        [stats["stats"]["duration"]["mean"], "bigstat-mean-duration", "ms"],
        [stats["stats"]["duration"]["max"],  "bigstat-max-duration", "ms"],
        [stats["conc"].andand["max"],               "bigstat-max-conc", ""],
      ].each do |value, title, units|
        result << {bind: title, value: value, units: units}
      end
      result
    end

    def error_count(status_counts)
      status_counts.inject(0) {|m,(s,c)| (s !~ /^[32]/ && s != "404") ? m + c : m }
    end

    def stats_time_series(title, buckets, reach_in: proc {|d| d})
      result = {title: title, series: []}

      buckets.each do |time, stats|
        result[:series] << [time, reach_in[stats]]
      end
      result
    end

    def table(data, sort_field: proc {|d| 1}, reach_in: proc {|d| d }, link: proc {|n,i| nil})
      table = []
      sorted_data = data.to_a.sort_by {|_,d| sort_field[d]}.reverse
      sorted_data.each_with_index do |(name, data), i|
        data = reach_in[data]
        row = []
        row << {showDatabox: link[name,i], content: [*name].join(" "), style: "font-family: monospace;"}

        [
          data["stats"]["count"],
          error_count(data["stats"]["status"]),
          data["stats"]["duration"]["mean"],
          data["stats"]["duration"]["min"],
          data["stats"]["duration"]["max"],
          data["conc"].andand["max"]
        ].each do |cell|
          row << {content: cell}
        end
        table << row
      end
      table
    end

    def generate
      str = File.read("views/index.html")
      databoxes = {}
      databoxes["global"] = {title: "All frontends", breadcrumbs: [{databox: "global", text: "All"}]}
      databoxes["global"].merge!(boxes("All frontends", @stats["global"]))
      databoxes["global"]["table"] = table(@stats["frontends"], 
                                  sort_field: proc {|d| d["global"]["all"]["stats"]["count"]}, 
                                  reach_in: proc {|d| d["global"]["all"] },
                                  link: proc {|n,i| "frontend-#{n}" })

      @stats["frontends"].each do |name, data|
        databoxes["frontend-#{name}"] = {
          title: "Frontend #{name}", 
          breadcrumbs: [{databox: "global", text: "All"}, {databox: "frontend-#{name}", text: "#{name}"}]
        }
        databoxes["frontend-#{name}"].merge!(boxes(name, data["global"]))

        new_data = {}
        data["paths"].each do |path, methods|
          methods.each do |method, data|
            new_data[[method, path]] = data
          end
        end
        databoxes["frontend-#{name}"]["table"] = 
           table(new_data,
                   sort_field: proc {|d| d["all"]["stats"]["count"] },
                   reach_in: proc {|d| d["all"] },
                   link: proc {|n,i| "frontend-#{name}-path-#{i}" })

        i = 0
        sorted_data = new_data.to_a.sort_by {|_,d| d["all"]["stats"]["count"]}.reverse
        sorted_data.each do |(method, path), path_data|
          databox = {
            title: "Frontend #{name} / #{method} #{path}",
            breadcrumbs: [
              {databox: "global", text: "All"}, 
              {databox: "frontend-#{name}", text: "#{name}"}, 
              {databox: "frontend-#{name}-path-#{i}", text: "#{method} #{path}"}
            ]
          }
          databox.merge!(boxes("#{name} / #{method} #{path}", path_data))
          databoxes["frontend-#{name}-path-#{i}"] = databox
          i += 1
        end
      end

      js = [""]
      js << "Hawat.databoxes = #{JSON.pretty_generate(databoxes)}"
      js << "$(document).ready(function() { Hawat.displayDatabox('global') })"
      File.open("output.html", "w") do |fout|
        str = str.sub("JAVASCRIPT", js.join("\n"))
        fout.puts str
      end
    end

  end
end

