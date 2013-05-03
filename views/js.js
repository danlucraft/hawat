
// Load the Visualization API and the piechart package.
google.load('visualization', '1.0', {'packages':['corechart']});

var Hawat = {
  breadCrumbs: [],
  showDataBox: function(name) {
    $(".databox").each(function(i, el) {
      if ($(el).attr("id") == name) {
        $(el).show()
      } else {
        $(el).hide()
      }
    })

  }
}
