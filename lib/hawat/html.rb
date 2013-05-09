
class Hawat
  class Html
    def initialize(stats)
      @stats = stats
    end

    def stats_boxes(box, stats)
      box["boxes"] = []
      [
        [stats["stats"]["count"],                "bigstat-requests", ""],
        [error_count(stats["stats"]["status"]),  "bigstat-errors", ""],
        [stats["stats"]["duration"]["mean"], "bigstat-mean-duration", "ms"],
        [stats["stats"]["duration"]["max"],  "bigstat-max-duration", "ms"],
        [stats["conc"]["max"],               "bigstat-max-conc", ""],
      ].each do |value, title, units|
        box["boxes"] << {bind: title, value: value, units: units}
      end
    end

    def error_count(status_counts)
      status_counts.inject(0) {|m,(s,c)| (s !~ /^2/ && s != "404") ? m + c : m }
    end

    def stats_time_series(box, bind, title, buckets, reach_in: proc {|d| d})
      box[bind] = {title: title, series: []}

      buckets.each do |time, stats|
        box[bind][:series] << [time, reach_in[stats]]
      end
    end

    def table(box, data, sort_field: proc {|d| 1}, reach_in: proc {|d| d }, link: proc {|n,i| nil})
      box["table"] = []
      sorted_data = data.to_a.sort_by {|_,d| sort_field[d]}.reverse
      sorted_data.each_with_index do |(name, data), i|
        data = reach_in[data]
        row = []
        row << {showDatabox: link[name,i], content: [*name].join(" ")}

        [
          data["stats"]["count"],
          error_count(data["stats"]["status"]),
          data["stats"]["duration"]["mean"],
          data["stats"]["duration"]["min"],
          data["stats"]["duration"]["max"],
          data["conc"]["max"]
        ].each do |cell|
          row << {content: cell}
        end
        box["table"] << row
      end
    end

    def boxes(box, title, data)
      stats_boxes(box, data["all"])
      box["charts"] = {}
      [
        ["requests",      "Requests",        proc {|d| d["stats"]["count"] },             ],
        ["errors",        "Errors",          proc {|d| error_count(d["stats"]["status"]) }],
        ["mean-duration", "Mean Latency",    proc {|d| d["stats"]["duration"]["mean"] }   ],
        ["max-duration",  "Max Latency",     proc {|d| d["stats"]["duration"]["max"] }    ],
        ["max-conc",      "Max Concurrency", proc {|d| d["conc"]["max"] }                 ],
      ].each do |bind, sub_title, fetch|
        stats_time_series(box["charts"], bind, "#{title} #{sub_title}", data["series"], reach_in: fetch)
      end
    end

    def generate
      str = File.read("views/index.html")
      databox = {title: "All frontends", breadcrumbs: [{databox: "global", text: "All"}]}
      boxes(databox, "All frontends", @stats["global"])
      table(databox, @stats["frontends"], 
              sort_field: proc {|d| d["global"]["all"]["stats"]["count"]}, 
              reach_in: proc {|d| d["global"]["all"] },
              link: proc {|n,i| "frontend-#{n}" })
      js = [""]
      js << "Hawat.databoxes[\"global\"] = #{databox.to_json}"
      js << "$(document).ready(function() { Hawat.displayDatabox('global') })"

      @stats["frontends"].each do |name, data|
        databox = {title: "Frontend #{name}", breadcrumbs: [{databox: "global", text: "All"}, {databox: "frontend-#{name}", text: "#{name}"}]}
        boxes(databox, name, data["global"])
        new_data = {}
        data["paths"].each do |path, methods|
          methods.each do |method, data|
            new_data[[method, path]] = data
          end
        end
        table(databox, new_data,
              sort_field: proc {|d| d["all"]["stats"]["count"] },
              reach_in: proc {|d| d["all"] },
              link: proc {|n,i| "frontend-#{name}-path-#{i}" })

        js << "Hawat.databoxes[\"frontend-#{name}\"] = #{databox.to_json}"

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
          boxes(databox, "#{name}, #{method} #{path}", path_data)
          js << "Hawat.databoxes[\"frontend-#{name}-path-#{i}\"] = #{databox.to_json}"
          i += 1
        end
      end

      File.open("output.html", "w") do |fout|
        str = str.sub("JAVASCRIPT", js.join("\n"))
        fout.puts str
      end
    end

  end
end

