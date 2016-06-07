var ids = [];
var clicked = false;
var clicked_sess = "";

$().ready(function()
{
  $(".item").click(function () {
    var id = $(this).attr("id");
    if (!ids.includes(id) && !clicked) {
      $(this).append("<input id='name' />");
      ids.push(id);
      clicked = true;
      clicked_sess = $(this).attr("session");
    }
  });

  $("#button").click(function () {
    if (!clicked) return;
    if ($("#name").val()=="") return;
    $.ajax({url: "pool_save.php?name="+encodeURIComponent($("#name").val())+"&session="+encodeURIComponent(clicked_sess), success: function(result){
      if (result=="ok") {
        window.location = "http://postedit.cl.uni-heidelberg.de/interface.php?key="+clicked_sess+"&ui_type=t"; // FIXME
      } else {
        alert("Session taken, choose another session.");
      }
    }});
  });
});

