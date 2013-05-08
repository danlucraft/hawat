
class Hawat
  class Html
    def initialize(stats)
      @stats = stats
    end

    def stats_boxes(js, stats)
      chart_ids = []
      @boxes_id ||= 0
      js << "boxes: ["
      [
        [stats["stats"]["count"],                "bigstat-requests", ""],
        [error_count(stats["stats"]["status"]),  "bigstat-errors", ""],
        [stats["stats"]["duration"]["mean"], "bigstat-mean-duration", "ms"],
        [stats["stats"]["duration"]["max"],  "bigstat-max-duration", "ms"],
        [stats["conc"]["max"],               "bigstat-max-conc", ""],
      ].each do |value, title, units|
        @boxes_id += 1
        chart_id = title.gsub(" ", "-").downcase.gsub(/[^a-z0-9]/, "") + @boxes_id.to_s
        js << (<<-JS).chomp
          {"bind": "#{title}", "value": #{value}, "units": "#{units}"},
        JS
        chart_ids << chart_id
      end
      js << "],"
      chart_ids
    end

    def error_count(status_counts)
      status_counts.inject(0) {|m,(s,c)| (s !~ /^2/ && s != "404") ? m + c : m }
    end

    def stats_time_series(js, bind, title, buckets, reach_in: proc {|d| d}, chart_id: nil, display: false)
      js << "  \"#{bind}\": {"
      js << "    title: \"#{title}\","
      js << "    series: ["
      buckets.each do |time, stats|
        js << "      ['#{time}', #{reach_in[stats]}],"
      end
      js << "    ]"
      js << "  },"
    end

    def table(js, data, sort_field: proc {|d| 1}, reach_in: proc {|d| d }, link: proc {|n,i| nil})
      js << "  table: ["
      sorted_data = data.to_a.sort_by {|_,d| sort_field[d]}.reverse
      sorted_data.each_with_index do |(name, data), i|
        data = reach_in[data]
        js << "     ["
        js << {showDatabox: link[name,i], content: [*name].join(" ")}.to_json + ","

        [
          data["stats"]["count"],
          error_count(data["stats"]["status"]),
          data["stats"]["duration"]["mean"],
          data["stats"]["duration"]["min"],
          data["stats"]["duration"]["max"],
          data["conc"]["max"]
        ].each do |cell|
          js << {content: cell}.to_json + ","
        end
        js << "     ],"
      end
      js << "  ],"
    end

    TITLE = "Hawat"

    def boxes(js, title, data, display: false)
      chart_ids = stats_boxes(js, data["all"])
      ids = chart_ids.clone
      first = true
      js << "charts: {"
      [
        ["requests",      "Requests",        proc {|d| d["stats"]["count"] },             ],
        ["errors",        "Errors",          proc {|d| error_count(d["stats"]["status"]) }],
        ["mean-duration", "Mean Latency",    proc {|d| d["stats"]["duration"]["mean"] }   ],
        ["max-duration",  "Max Latency",     proc {|d| d["stats"]["duration"]["max"] }    ],
        ["max-conc",      "Max Concurrency", proc {|d| d["conc"]["max"] }                 ],
      ].each do |bind, sub_title, fetch|
        id = stats_time_series(js, bind, "#{title} #{sub_title}", data["series"], reach_in: fetch, chart_id: ids.shift, display: first)
        first = false
      end
      js << "},"
      chart_ids
    end

    def generate
      str = File.read("views/index.html")
      js = [""]#; File.read("views/js.js")
      js << "Hawat.databoxes[\"global\"] = {"
      js << "  title: \"All frontends\","
      js << "  breadcrumbs: [{databox: \"global\", text: \"All\"}],"
      chart_ids = boxes(js, "All frontends", @stats["global"], display: true)
      table(js, @stats["frontends"], 
              sort_field: proc {|d| d["global"]["all"]["stats"]["count"]}, 
              reach_in: proc {|d| d["global"]["all"] },
              link: proc {|n,i| "frontend-#{n}" })
      js << "}"
      js << "$(document).ready(function() { Hawat.displayDatabox('global') })"
      js << ""

      @stats["frontends"].each do |name, data|
        js << "Hawat.databoxes[\"frontend-#{name}\"] = {"
        js << "  title: \"Frontend #{name}\","
        js << "  breadcrumbs: [{databox: \"global\", text: \"All\"}, {databox: \"frontend-#{name}\", text: \"#{name}\"}],"
        boxes(js, name, data["global"], display: false)
        new_data = {}
        data["paths"].each do |path, methods|
          methods.each do |method, data|
            new_data[[method, path]] = data
          end
        end
        table(js, new_data,
              sort_field: proc {|d| d["all"]["stats"]["count"] },
              reach_in: proc {|d| d["all"] },
              link: proc {|n,i| "frontend-#{name}-path-#{i}" })
        js << "}"

        i = 0
        new_data.each do |(method, path), path_data|
          js << "Hawat.databoxes[\"frontend-#{name}-path-#{i}\"] = {"
          js << "  title: \"Frontend #{name} / #{method} #{path}\","
          js << "  breadcrumbs: [{databox: \"global\", text: \"All\"}, {databox: \"frontend-#{name}\", text: \"#{name}\"}, {databox: \"frontend-#{name}-path-#{i}\", text: \"#{method} #{path}\"}],"
          i += 1
          boxes(js, "#{name}, #{method} #{path}", path_data, display: false)
          js << "}"
        end
      end

      File.open("output.html", "w") do |fout|
        str = str.sub("JAVASCRIPT", js.join("\n"))
        fout.puts str
      end
    end

  end
end

