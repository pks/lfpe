$().ready(function()
{
  // use ajax to send commands to the server
  $(".ajax").each(function(x){
    $(this).click(function(){
       $.ajax({url: $(this).attr("tgt"), success: function(result){
          $("#control_reply").html(result);
      }});
    })
  })

  // display svg
  var d = atob(document.getElementById("svg_b64").innerHTML);
  $('#svg').append($('<svg width="10000px">'+d+'</svg>'));
  d = atob(document.getElementById("original_svg_b64").innerHTML);
  $('#original_svg').append($('<svg width="10000px">'+d+'</svg>'));
});

