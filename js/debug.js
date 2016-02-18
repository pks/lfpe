var poll_debug = function (url_prefix)
{
  setTimeout(function(){
     $.get(url_prefix+"/status_debug").done(function(response){
       $("#status").text(response);
       poll(url_prefix);
     });
  }, 3000);
}

$().ready(function() {

  // send commands using ajax
  $(".ajax").each(function(x) {
    $(this).click(function() {
       $.ajax({url: $(this).attr("tgt"), success: function(result){
          $("#control_reply").html(result);
      }});
    })
  })
  $("#features").click(function() { if (this.value=="Feature") this.value = ""; });
  $("#features").focusout(function() { if (this.value == "") this.value = "Feature"; });
  $("#features_get").click(function() { if (this.value=="Feature") this.value = ""; });
  $("#features_get").focusout(function() { if (this.value == "") this.value = "Feature"; });
  $("#features_value").click(function() { this.value = ""; });
  $("#features_value").focusout(function() { if (this.value == "") this.value = "1e-05"; });
  $("#features_value_get").click(function() { this.value = ""; });
  $("#features_value_get").focusout(function() { if (this.value == "") this.value = "1e-05"; });
  $("#feature_groups_value").click(function() { this.value = ""; });
  $("#feature_groups_value").focusout(function() { if (this.value == "") this.value = "1e-05"; });
  // set/get all sorts of learning rates
  $("#set_features").click(function() {
    k = $("#features").val();
    v = $("#features_value").val();
    if (k=="Feature" || k=="" || v=="" || isNaN(parseFloat(v))) {
      alert("Malformed request.");
    } else {
      url_prefix = $("#features_type").val();
      $.ajax({url: url_prefix+"/"+k+"/"+v, success: function(result){
         $("#control_reply").html(result);
      }});
    }
  });
  $("#set_feature_groups").click(function() {
    k = $("#feature_groups").val();
    v = $("#feature_groups_value").val();
    if (v=="" || !parseFloat(v)) {
      alert("Malformed request.");
    } else {
       $.ajax({url: "/set_learning_rates/"+k+"/"+v, success: function(result){
          $("#control_reply").html(result);
      }});
    }
  });
  $("#get_features").click(function () {
    $.get("http://"+document.URL.split("/")[2]+$("#features_type_get").val()+"/"+$("#features_get").val(),
    function (data) {
      $("#features_value_get").val(data);
    });
  });
  $("#get_feature_groups").click(function () {
    $.get("http://"+document.URL.split("/")[2]+"/get_rate/"+$("#feature_groups_get").val(),
    function (data) {
      $("#feature_groups_value_get").val(data);
    });
  });

  // sortable tables
  // src: http://stackoverflow.com/questions/4126206/javascript-parsefloat-1-23e-7-gives-1-23e-7-when-need-0-000000123
  $.tablesorter.addParser({
  id: 'scinot',
  is: function(s) {
    return /[+\-]?(?:0|[1-9]\d*)(?:\.\d*)?(?:[eE][+\-]?\d+)?/.test(s);
  },
  format: function(s) {
    return $.tablesorter.formatFloat(s);
  },
  type: 'numeric'
  });
  $("table.sortable").each(function(x) {
    $(this).tablesorter({widgets: ['zebra']});
  });
  $(".toggle").each(function(x) {
    $(this).click(function() {
      $(this).next().toggle();
    })
  });
  $("table.kbest_features tr:odd").css("background-color", "#87cefa");
  $("table.kbest_features tr:even").css("background-color", "#fff");

  // display svg
  var d = atob(document.getElementById("svg_b64").innerHTML);
  $('#svg').append(
    $('<svg width="100%">'+d+'</svg>')
  );
  $("#svg").width($("#svg").children()[0].getBBox().width+"px");
  d = atob(document.getElementById("original_svg_b64").innerHTML);
  $('#original_svg').append(
    $('<svg width="100%">'+d+'</svg>')
  );
  $("#original_svg").width($("#original_svg").children()[0].getBBox().width+"px");

  // mark stale content
  if ($("#up_val").text() != "true") {
    $(".updated").each(function(i,el){$(el).addClass("stale")})
  }

  // get current status + input ID
  poll_debug("http://"+document.URL.split("/")[2]);

});

