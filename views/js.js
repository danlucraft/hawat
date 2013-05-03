
// Load the Visualization API and the piechart package.
google.load('visualization', '1.0', {'packages':['corechart']});

var Hawat = {
  breadCrumbs: [],
  showDataBox: function(name) {
    $(".databox").each(function(i, el) {
      if ($(el).attr("id") == name) {
        $(el).show()
        $(el).find(".chart").each(function(i, el) {
          var chartDrawerName = $(el).attr("data-function")
          var chartDrawer = Hawat[chartDrawerName]
          chartDrawer()
        })
      } else {
        $(el).hide()
      }
    })

  }
}
