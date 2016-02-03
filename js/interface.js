/*
 * (common) global vars
 *
 */
var data,    // global data object
    ui_type; // 't' (text) or 'g' (graphical)

/*
 * cross-site request
 *
 */
var create_cors_req = function (method, url)
{
  var xhr = new XMLHttpRequest();
  if ("withCredentials" in xhr) {
    xhr.open(method, url, true);
    xhr.setRequestHeader('Content-type', 'application/x-www-form-urlencoded; charset=UTF-8');
  } else {
    xhr = null;
  }

  return xhr;
}

/*
 * Timer
 *
 */
var Timer = {
  start_t: 0,
  pause_start_t: 0,
  pause_acc_t: 0,
  paused: false,

  start: function () {
    this.start_t = Date.now();
    this.pause_start_t = 0;
    this.pause_acc_t = 0;
    this.paused = false;
  },
  pause: function () {
    this.paused = true;
    this.pause_start_t = Date.now();
  },
  unpause: function () {
    this.paused = false;
    this.pause_acc_t += Date.now()-this.pause_start_t;
    this.pause_start_t = 0;
  },
  get: function () {
    return (Date.now()-this.start_t)-this.pause_acc_t;
  }
}

/*
 * pause/unpause timer
 *
 */
var pause = function ()
{
  var paused          = document.getElementById("paused");
  var button          = document.getElementById("pause_button");
  var next_button     = document.getElementById("next");
  var target_textarea = document.getElementById("target_textarea")
  var initialized     = document.getElementById("init");

  if (paused.value == 0) {
    button.innerHTML = "Unpause";
    paused.value = 1;
    next.setAttribute("disabled", "disabled");
    target_textarea.setAttribute("disabled", "disabled");
    Timer.pause();
  } else {
    button.innerHTML = "Pause";
    paused.value = 0;
    next.removeAttribute("disabled");
    if (initialized.value != "") {
      target_textarea.removeAttribute("disabled");
    }
    Timer.unpause();
  }
}

/*
 * no newline on return in textarea
 *
 */
var catch_return = function (e)
{
  if (e.keyCode == 13) {
    e.preventDefault();
    next();
  }

  return false;
}

/*
 * working/not working
 *
 */
var working = function ()
{
  // elements
  var button              = document.getElementById("next");
  var pause_button        = document.getElementById("pause_button");
  var target_textarea     = document.getElementById("target_textarea")
  var raw_source_textarea = document.getElementById("raw_source_textarea");
  var current_seg_id      = document.getElementById("current_seg_id");
  var source              = document.getElementById("source");
  var status              = document.getElementById("status");
  var oov_correct         = document.getElementById("oov_correct");
  var last_post_edit      = document.getElementById("last_post_edit");

  if ($("#ui_type").val() == "t") {
    $("#textboxes").fadeTo(200,0.1);
  } else {
    $("#derivation_editor").fadeTo(200,0.1);
  }

  // show 'working' message
  $("#status").fadeToggle();

  // disable button and textarea
           button.setAttribute("disabled", "disabled");
     pause_button.setAttribute("disabled", "disabled");
  target_textarea.setAttribute("disabled", "disabled");
  document.getElementById("reset_button").setAttribute("disabled", "disabled");

  DE_locked = true;
}
function not_working(fadein=true)
{
  document.getElementById("reset_button").removeAttribute("disabled");
  // elements
  var button              = document.getElementById("next");
  var pause_button        = document.getElementById("pause_button");
  var target_textarea     = document.getElementById("target_textarea")
  var raw_source_textarea = document.getElementById("raw_source_textarea");
  var current_seg_id      = document.getElementById("current_seg_id");
  var source              = document.getElementById("source");
  var status              = document.getElementById("status");
  var oov_correct         = document.getElementById("oov_correct");
  var last_post_edit      = document.getElementById("last_post_edit");

  if (fadein) {
  if ($("#ui_type").val() == "t") {
    $("#textboxes").fadeTo(200,1);
  } else {
    $("#derivation_editor").fadeTo(200,1);
  }
  }

  // hide 'working' message
  $("#status").fadeToggle();

  // enable buttons
          document.getElementById("next").removeAttribute("disabled");
  document.getElementById("pause_button").removeAttribute("disabled");
  document.getElementById("reset_button").removeAttribute("disabled");

  DE_locked = false;
}

/*
 * polling the server
 *
 */
var poll = function (url_prefix)
{
  setTimeout(function(){
     $.get(url_prefix+"/status").done(function(response){
       $("#status_detail").text(response);
       if (response == "Ready") {
         ready = true;
         request_and_process_next();
         return;
       } else {
         poll(url_prefix);
       }
     });
  }, 1000);
}

/*
 * next button
 *
 */
var next =  function ()
{
  // elements
  var button              = document.getElementById("next");
  var pause_button        = document.getElementById("pause_button");
  var target_textarea     = document.getElementById("target_textarea")
  var raw_source_textarea = document.getElementById("raw_source_textarea");
  var current_seg_id      = document.getElementById("current_seg_id");
  var source              = document.getElementById("source");
  var status              = document.getElementById("status");
  var oov_correct         = document.getElementById("oov_correct");
  var last_post_edit      = document.getElementById("last_post_edit");

  working();

  // get metadata stored in DOM
  var base_url = "http://coltrane.cl.uni-heidelberg.de";
  var port     = document.getElementById("port").value;
  var key      = document.getElementById("key").value;

  // url
  next_url = base_url+":"+port+"/next";

  // post edit
  var post_edit = '';
  var send_data = new Object();

  // extract data from interfaces
  if (ui_type == 'g') {
    data_s = DE_extract_data();
    if (!data_s) {
      not_working();
      return;
    }
    send_data = JSON.parse(data_s);
    post_edit = $.trim(send_data["target"].join(" "));
    if (DE_target_done.length != DE_target_shapes.length)
      post_edit = "";
    send_data["post_edit"] = encodeURIComponent(post_edit);
    send_data['type'] = 'g';
    send_data["original_svg"] = document.getElementById("original_svg").value;
  } else {
    post_edit = $.trim(target_textarea.value);
    send_data["post_edit"] = post_edit;
    send_data['type'] = 't';
  }

  send_data["key"] = key;

  // send data
  if (oov_correct.value=="false" && post_edit != "") {
      send_data["EDIT"] = true;
      send_data["duration"] = Timer.get();
      send_data["source_value"] = encodeURIComponent(source.value);
      // compose request
      // no change?
      if (post_edit == last_post_edit.value) {
        send_data["nochange"] = true;
      }
      // update document overview
      document.getElementById("seg_"+(current_seg_id.value)+"_t").innerHTML=decodeURIComponent(post_edit);
  // OOV correction mode
  } else if (oov_correct.value=="true") {
     send_data["OOV"] = true;
     var l = document.getElementById("oov_num_items").value;
     var src = [];
     var tgt = [];
     for (var i=0; i<l; i++) {
       src.push(encodeURIComponent($.trim(document.getElementById("oov_src"+i).value)));
       tgt.push(encodeURIComponent($.trim(document.getElementById("oov_tgt"+i).value)));
       if (tgt[tgt.length-1] == "") { // empty correction
         alert("Please provide translations for all words.");
         not_working();

         return;
       }
     }
     var l = document.getElementById("oov_fields").children.length;
     for (var i=0; i<l; i++)
       { document.getElementById("oov_fields").children[0].remove(); }
    $("#oov_form").toggle("blind");
    $("#next").val("Next");
     send_data["correct"] = src.join("\t") + " ||| " + tgt.join("\t");
  } else {
    if (source.value != "") {
      alert("Please provide a post-edit and mark all phrases as finished.");
      target_textarea.removeAttribute("disabled", "disabled");
         pause_button.removeAttribute("disabled", "disabled");
               button.removeAttribute("disabled", "disabled");
      not_working();
      return;
    }
  }

  // confirm to server
  /*if (document.getElementById("init").value != "") {
    var xhr_confirm = create_cors_req('get', base_url+":"+port+"/confirm");
    xhr_confirm.send(); // FIXME handle errors
  }*/

  // build request
  var xhr = create_cors_req('post', next_url);
  if (!xhr) {
    alert("Error: 2"); // FIXME do something reasonable
  }
  xhr.onerror = function (e) { alert("XHR ERRROR 1x " + e.target.status); }
  xhr.send(JSON.stringify(send_data)); // send 'next' request
  xhr.onload = function() {
    poll(base_url+":"+port);
  }
}

var request_and_process_next = function ()
{
  // elements
  var button              = document.getElementById("next");
  var pause_button        = document.getElementById("pause_button");
  var target_textarea     = document.getElementById("target_textarea")
  var raw_source_textarea = document.getElementById("raw_source_textarea");
  var current_seg_id      = document.getElementById("current_seg_id");
  var source              = document.getElementById("source");
  var status              = document.getElementById("status");
  var oov_correct         = document.getElementById("oov_correct");
  var last_post_edit      = document.getElementById("last_post_edit");

  // get metadata stored in DOM
  var base_url = "http://coltrane.cl.uni-heidelberg.de";
  var port     = document.getElementById("port").value;
  var key      = document.getElementById("key").value;

  // url
  next_url = base_url+":"+port+"/next";

  var xhr = create_cors_req('get', base_url+":"+port+"/fetch");
  if (!xhr) {
    alert("Error: 2"); // FIXME do something reasonable
  }
  xhr.onerror = function (e) { alert("XHR ERRROR 1 " + e.target.status); }
  xhr.send(); // send 'next' request

  // 'next' request's callbacks
  xhr.onload = function() {
    if (xhr.readyState != 4 || xhr.status!=200) { alert("XHR ERROR 2"); return; }

    document.getElementById("init").value = 1; // for pause()
     // translation system is currently handling a request
     // FIXME maybe poll server for result?
     if (xhr.responseText == "locked") {
       alert("Translation system is locked, try again in a moment (reload the page and click 'Start/Continue').");
       not_working();

       return;
     }

    data = JSON.parse(xhr.responseText)
    document.getElementById("data").value = xhr.responseText;

    // done, disable interface
    if (data["fin"]) {
      target_textarea.setAttribute("disabled", "disabled");
      status.style.display              = "none";
      button.innerHTML                  = "Session finished, thank you!";
      $("#raw_source_textarea").html("");
      $("#target_textarea").val("");
      $("#target_textarea").attr("rows", 1);
            button.setAttribute("disabled", "disabled");
      pause_button.setAttribute("disabled", "disabled");
      if (current_seg_id.value)
        $("#seg_"+current_seg_id.value).removeClass("bold");

      return;

    // enter OOV correct mode
    } else if (data["oovs"]) {
      var append_to = document.getElementById("oov_fields");
      document.getElementById("oov_num_items").value = data["oovs"].length;
      if ($("#ui_type").val() == "t") {
        $("#textboxes").fadeTo(200,0.1);
      } else {
        $("#derivation_editor").fadeTo(200,0.1);
      }
      $("#oov_context").html(data["raw_source"].replace(/\*\*\*/g,"<u>").replace(/###/g,"</u>"));
      for (var i=0; i<data["oovs"].length; i++) {
        var node_src = document.createElement("input");
        var node_tgt = document.createElement("input");
        node_src.type = "text";
        node_tgt.type = "text";
        node_src.id = "oov_src"+i;
        node_tgt.id = "oov_tgt"+i;
        node_src.value = data["oovs"][i];
        node_src.setAttribute("disabled", "disabled");
        append_to.appendChild(node_src);
        append_to.appendChild(node_tgt);
        append_to.appendChild(document.createElement("br"));
        $("#oov_src"+i).attr({width: 'auto', size: $("#oov_src"+i).val().length});
        node_tgt.onkeypress = function (event) {
          $(this).attr({width: 'auto', size: 5+$(this).val().length});
          catch_return(event);
        }
      }
      oov_correct.value = true;

      $("#oov_form").toggle("blind");
      $("#next").html("Next");
      $("#oov_tgt0").focus();
      not_working(false);
      DE_locked = true;

    // translation mode
    } else {
      if ($("#ui_type").val() == "t") {
        $("#textboxes").fadeTo(200,1);
      } else {
        $("#derivation_editor").fadeTo(200,1);
      }

      var id          = data["progress"];
      var src         = data["source"];
      var translation = data["transl_detok"];
      var raw_source  = data["raw_source"];

      // update interface
      oov_correct.value         = false;
      status.style.display      = "none";
      if (!translation) {
        target_textarea.value   = "";
      } else {
        target_textarea.value   = translation;
      }
      //raw_source_textarea.value = raw_source;
      $("#raw_source_textarea").html(raw_source);
      button.innerHTML          = "Next";
               button.removeAttribute("disabled");
      target_textarea.removeAttribute("disabled", "disabled");
         pause_button.removeAttribute("disabled", "disabled");
         document.getElementById("reset_button").removeAttribute("disabled");
      document.getElementById("seg_"+id).className += " bold";
      if (id > 0) {
        $("#seg_"+(id-1)).removeClass("bold");
      }
      if (translation)
        target_textarea.rows     = Math.round(translation.length/80+0.5);
      //raw_source_textarea.rows = Math.round(raw_source.length/80+0.5);
      target_textarea.focus();
      target_textarea.selectionStart = 0;
      target_textarea.selectionEnd   = 0;

      // remember aux data in DOM
      current_seg_id.value = id;
      source.value         = src;
      last_post_edit.value = translation;

      // confirm to server
      var xhr_confirm = create_cors_req('get', base_url+":"+port+"/confirm");
      xhr_confirm.send(); // FIXME handle errors

      // load data into graphical UI
      if (ui_type == "g") {
        DE_init();
        var x = $.trim(JSON.parse(DE_extract_data())["target"].join(" "));
        last_post_edit.value = x;
        document.getElementById("original_svg").value = DE_get_raw_svg_data();
      }

      // start timer
      Timer.start();
    }
  };

  return;
}

/*
 * init text interface
 *
 */
var init_text_editor = function ()
{
  document.getElementById("target_textarea").value     = "";
  document.getElementById("target_textarea").setAttribute("disabled", "disabled");

  return false;
}

/*
 * init site
 *
 */
$().ready(function()
{
  // reset vars
  document.getElementById("source").value              = "";
  document.getElementById("current_seg_id").value      = "";
  document.getElementById("paused").value              = "";
  document.getElementById("oov_correct").value         = false;
  document.getElementById("displayed_oov_hint").value  = false;
  document.getElementById("init").value                = "";
  document.getElementById("reset_button").setAttribute("disabled", "disabled");

  not_working();

  ui_type = document.getElementById("ui_type").value;

  // graphical derivation editor
  if (ui_type == "g") {
    document.getElementById("derivation_editor").style.display = "block";

  // text based editor
  } else {
    init_text_editor();
    document.getElementById("textboxes").style.display = "block";
  }

});

