$().ready(function()
{
  $(".ajax").each(function(x){
    $(this).click(function(){
       $.ajax({url: $(this).attr("tgt"), success: function(result){
          $("#ajax_result").html(result);
      }});   
    })
  })
  
  var d = atob(document.getElementById("svg_b64").innerHTML); 
  $('#svg').append($('<svg width="10000px">'+d+'</svg>'));

})

