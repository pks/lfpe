$().ready(function()
{
  $(".ajax").each(function(x){
    $(this).click(function(){
       $.ajax({url: $(this).attr("tgt"), success: function(result){
          $("#ajax_result").html(result);
      }});   
    })
  })
})

$("#reset").click(function(){

}); 
