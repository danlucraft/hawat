
// Load the Visualization API and the piechart package.
google.load('visualization', '1.0', {'packages':['corechart']});
var time = function(name, func) {
  var yourBirthDate = new Date()
  func()
  var ms = new Date() - yourBirthDate;
  console.log(name + " " + ms)
}

var Hawat = {
  breadCrumbs: [],
  drawn: {},
  showDataBox: function(name) {
    console.profile()
    time("showDataBox", function() {
      $(".databox").each(function(i, el) {
        time("  databox " + $(el).attr("id"), function() {

          if ($(el).attr("id") == name) {
            time("    show el", function() {
              $(el).show()
              var first = true
              $(el).find(".chart").each(function(i, el2) {
                var chartDrawerName = $(el2).attr("data-function")
                var chartDrawer = Hawat[chartDrawerName]
                if (!Hawat.drawn[chartDrawerName]) {
                  time("      draw chart", function() {
                    chartDrawer()
                  })
                  Hawat.drawn[chartDrawerName] = true
                console.log(Hawat.drawn)
                }
                if (first) {
                  $(el2).show()
                }
                first = false
              })
            })
          } else {
            $(el).hide()
          }

        })
      })
    })
    console.profileEnd()
  },


  displayChart: function(idfrag) {
                  $(".chart").each(function(i, el) {
                    $(el).hide()
                    if ($(el).attr("id") == "chart-" + idfrag) {
                      $(el).show()
                    }
                  })
                }

}
