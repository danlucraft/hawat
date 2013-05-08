
// Load the Visualization API and the piechart package.
google.load('visualization', '1.0', {'packages':['corechart']});

var Hawat = {
  breadCrumbs: [],
  showDataBox: function(name) {
    $(".databox").each(function(i, el) {
      if ($(el).attr("id") == name) {
        $(el).show()
        var first = true
        $(el).find(".chart").each(function(i, el) {
          var chartDrawerName = $(el).attr("data-function")
          var chartDrawer = Hawat[chartDrawerName]
          chartDrawer()
          if (first) {
            $(el).show()
          }
          first = false
        })
      } else {
        $(el).hide()
      }
    })
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
