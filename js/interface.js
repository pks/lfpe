/*
 * Global vars
 *
 */
var data,    // global data object
    ui_type; // 't' (text) or 'g' (graphical)

var TEXT_count_click=0,
    TEXT_count_kbd=0;

var rules_orig = {};

var NEXT_MODE = "get"; // or "rate"
var SLIDER = null;
var DONE = false;

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

var TimerRating = {
  start_t: 0,
  pause_start_t: 0,
  pause_acc_t: 0,
  paused: false,
  value: -1,

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
  stop: function() {
    this.value = (Date.now()-this.start_t)-this.pause_acc_t;
  },
  get: function () {
    if (this.value < 0) {
      return (Date.now()-this.start_t)-this.pause_acc_t;
    } else {
      return this.value;
    }
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
  var reset_button    = document.getElementById("reset_button");
  var target_textarea = document.getElementById("target_textarea")
  var initialized     = document.getElementById("init");

  if (paused.value == 0) {
    button.innerHTML = "Unpause";
    paused.value = 1;
    next_button.setAttribute("disabled", "disabled");
    reset_button.setAttribute("disabled", "disabled");
    Timer.pause();
    TimerRating.pause();
    if (ui_type=='g') {
      $("#derivation_editor").fadeTo(200,0.1);
      DE_ui_lock=true;
    }
    else target_textarea.setAttribute("disabled", "disabled");
  } else {
    button.innerHTML = "Pause";
    paused.value = 0;
    next_button.removeAttribute("disabled");
    if (NEXT_MODE != "rate")
      reset_button.removeAttribute("disabled", "disabled");
    Timer.unpause();
    TimerRating.unpause();
    if (ui_type=='g') {
      $("#derivation_editor").fadeTo(200,1);
      DE_ui_lock=false;
    }
    else {
      if (initialized.value != "") {
        target_textarea.removeAttribute("disabled");
      }
    }
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
    //next();
  }

  return false;
}

var TEXT_handle_keypress = function (e)
{
   if (e.keyCode == 13) {
    e.preventDefault();
    //next();
  }

  TEXT_count_kbd += 1;

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

  DE_ui_lock = true;
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

  DE_ui_lock = false;
}

/*
 * polling the server
 *
 */
var poll = function (url_prefix,rate=false,callback=function(){alert("Z");return false})
{
  setTimeout(function(){
     $.get(url_prefix+"/status").done(function(response){
       $("#status_detail").text(response);
       if (response == "Ready") {
         ready = true;
         request_and_process_next(rate,callback);
         return;
       } else {
         poll(url_prefix,rate,callback);
       }
     });
  }, 1000);
}

var wait_for_processed_postedit = function (url_prefix, seg_id)
{
  document.getElementById("seg_"+seg_id+"_t").innerHTML="<img height='20px' src='static/ajax-loader-large.gif'/>";
  setTimeout(function(){
     $.get(url_prefix+"/fetch_processed_postedit/"+seg_id).done(function(response){
       if (response != "") {
         document.getElementById("seg_"+seg_id+"_t").innerHTML = response;
         return;
       } else {
         wait_for_processed_postedit(url_prefix,seg_id);
       }
     });
  }, 3000);
}

var safe_str = function (s)
{
  return encodeURIComponent(JSON.stringify(s)).replace(/^%22/,"").replace(/%22$/,"");
}

/*
 * next button
 *
 */
var next = function()
{
  if (NEXT_MODE=="get") {
    nextX(true,next_callback);
    NEXT_MODE="rate";
  } else if (NEXT_MODE=="rate" && !DONE) {
    TimerRating.stop();
    Timer.start();
    $("#slider_wrapper").slideUp();
    $("#target_textarea").prop("disabled",false);
    //$("#pause_button").prop("disabled",false);
    $("#reset_button").prop("disabled",false);
    $("#next").html("Next");
    NEXT_MODE="get";
  }

  return false;
}

var next_callback = function (done=false)
{
  if (done) return false;
  NEXT_MODE = "rate";
  $("#slider_wrapper").slideDown();
  $("#original_mt_cmp").html($("#original_mt").val());
  SLIDER.set(50);
  TimerRating.start();

  return false;
}

var nextX =  function (rate=false,callback=function(){alert("X");return false})
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
  var base_url = "http://lemmy.cl.uni-heidelberg.de";
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
    if (document.getElementById("oov_correct").value != "true" && !DE_check_align()) {
      if(confirm("Not all phrases are aligned, continue?")) {
      } else {
        not_working();
        return;
      }
    }
    send_data = JSON.parse(data_s);
    post_edit = $.trim(send_data["target"].join(" "));
    if (DE_target_done.length != DE_target_shapes.length)
      post_edit = "";
    send_data["post_edit"] = safe_str(post_edit);
    send_data['type'] = 'g';
    send_data["original_svg"] = document.getElementById("original_svg").value;
    var dx = rule_diff(rules_orig, get_simplest_rules1());
    for (k in dx) {
      dx[k] = safe_str(dx[k]);
    }
    send_data["rule_diff"] = dx;
  } else {
    post_edit = $.trim(target_textarea.value);
    send_data["post_edit"] = safe_str(post_edit);
    send_data['type'] = 't';
    send_data["count_click"] = TEXT_count_click;
    send_data["count_kbd"] = TEXT_count_kbd;
  }

  send_data["key"] = key;
  send_data["name"] = safe_str($.trim($("#name").val()));
  send_data["rating"] = $("#rating").val();

  // send data
  if (oov_correct.value=="false" && post_edit != "") {
      send_data["EDIT"] = true;
      send_data["duration"] = Timer.get();
      send_data["duration_rating"] = TimerRating.get();
      send_data["source_value"] = safe_str(source.value);
      // compose request
      // no change?
      if (post_edit == last_post_edit.value) {
        send_data["nochange"] = true;
      }
      // update document overview
      wait_for_processed_postedit(base_url+":"+port, current_seg_id.value);
  // OOV correction mode
  } else if (oov_correct.value=="true") {
     send_data["OOV"] = true;
     var l = document.getElementById("oov_num_items").value;
     var src = [];
     var tgt = [];
     for (var i=0; i<l; i++) {
       src.push(safe_str($.trim(document.getElementById("oov_src"+i).value)));
       tgt.push(safe_str($.trim(document.getElementById("oov_tgt"+i).value)));
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
    $("#next").html("Next");
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

  // build request
  var xhr = create_cors_req('post', next_url);
  if (!xhr) {
    alert("Error: 2"); // FIXME do something reasonable
  }
  xhr.onerror = function (e) { alert("XHR ERRROR 1x " + e.target.status); }
  xhr.send(JSON.stringify(send_data)); // send 'next' request
  xhr.onload = function() {
    poll(base_url+":"+port,rate,callback);
  }
}

var request_and_process_next = function (rate=false,callback=function(){alert("Y");return false})
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
  var base_url = "http://lemmy.cl.uni-heidelberg.de";
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
     if (xhr.responseText == "locked") {
       alert("Translation system is locked, try again in a moment (reload the page and click 'Start/Continue').");
       not_working();

       return;
     }

    data = JSON.parse(xhr.responseText)

    var el = document.getElementById("seg_"+(data['progress']-1)+"_t");
    if (el && data['processed_postedit']) {
      el.innerHTML = data['processed_postedit'];
    }

    document.getElementById("data").value = xhr.responseText;

    // done, disable interface
    if (data["fin"]) {
      target_textarea.setAttribute("disabled", "disabled");
      DONE=true;
      status.style.display              = "none";
      //button.innerHTML                  = "-----";
      $("#view_summary").slideDown()
      $("#raw_source_textarea").html("");
      $("#target_textarea").val("");
      $("#target_textarea").attr("rows", 2);
            button.setAttribute("disabled", "disabled");
      pause_button.setAttribute("disabled", "disabled");
      if (current_seg_id.value)
        $("#seg_"+current_seg_id.value).removeClass("bold");

      return callback(true);

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
      if (ui_type == "g") {
        DE_ui_lock = true;
      }

      return false;

    // translation mode
    } else {
      if ($("#ui_type").val() == "t") {
        $("#textboxes").fadeTo(200,1);
      } else {
        $("#derivation_editor").fadeTo(200,1);
        $("#de_source").text(data["raw_source"]);
        $("#de_original_mt").text(data["transl_detok"]);
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
      if (rate) {
        $("#next").html("Rate");
      } else {
        $("#next").html("Next");
      }
      button.removeAttribute("disabled");
      pause_button.removeAttribute("disabled", "disabled");
      if (!rate) {
        target_textarea.removeAttribute("disabled", "disabled");
        document.getElementById("reset_button").removeAttribute("disabled");
      }
      document.getElementById("seg_"+id).className += " bold";
      if (id > 0) {
        $("#seg_"+(id-1)).removeClass("bold");
      }
      if (translation)
        target_textarea.rows     = Math.round(translation.length/80+0.5)+2;
      //raw_source_textarea.rows = Math.round(raw_source.length/80+0.5);
      target_textarea.focus();
      $("#original_mt").val(target_textarea.value);
      target_textarea.selectionStart = 0;
      target_textarea.selectionEnd   = 0;
      TEXT_count_click = 0;
      TEXT_count_kbd = 0;

      // remember aux data in DOM
      current_seg_id.value = id;
      source.value         = src;
      last_post_edit.value = translation;

      // confirm to server
      var xhr_confirm = create_cors_req('get', base_url+":"+port+"/confirm");
      xhr_confirm.send(); // FIXME handle errors

      // load data into graphical UI
      if (ui_type == "g") {
        DE_ui_lock = false;
        DE_init();
        var x = $.trim(JSON.parse(DE_extract_data())["target"].join(" "));
        last_post_edit.value = x;
        document.getElementById("original_svg").value = DE_get_raw_svg_data();
        rules_orig = get_simplest_rules1();
      }

      // start timer
      //Timer.start();

      return callback(false);
    }
  };

  return false;
}

/*
 * init text interface
 *
 */
var init_text_editor = function ()
{
  document.getElementById("target_textarea").value     = "";
  document.getElementById("target_textarea").setAttribute("disabled", "disabled");
  $("#pause_button").prop("disabled", true);
  $("#reset_button").prop("disabled", true);

  TEXT_count_click = 0;
  TEXT_count_kbd = 0;

  $("#target_textarea").click(function () {
    TEXT_count_click += 1;
  });

  return false;
}

var get_ui_type = function ()
{
  return document.getElementById("ui_type").value;
}

var reset = function ()
{
  var ui_type = get_ui_type();
  if (ui_type == "t") {
    if (!$("#init").val()) return;
    //TEXT_count_click = 0;
    //TEXT_count_kbd = 0;
    $("#target_textarea").val($("#original_mt").val());
  } else if (ui_type == "g") {
    DE_init(false);
    DE_update_str();
  }
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

  ui_type = get_ui_type();

  // graphical derivation editor
  if (ui_type == "g") {
    document.getElementById("derivation_editor").style.display = "block";

  // text based editor
  } else {
    init_text_editor();
    document.getElementById("textboxes").style.display = "block";
  }

  initSlider();
});

var initSlider = function ()
{
  var slider = document.getElementById("slider");
  SLIDER = noUiSlider.create(slider, {
        start: 50,
        range: {
                min: [0,1],
                max: [100]
        },
        pips: {
                mode: 'values',
                values: [],
                density:  25
        }
  });
  SLIDER.on("update", function (values, handle)
      {
        $("#rating").val(values[0]);
      });
}

var explore = function (o,src,tgt,s2t,t2s,done)
{
  if (done[o["id"]]) return;
  var d,other_t;
  if (o["type"] == "source") {
    d = s2t;
    src.push(o["id"]);
    other_t = "target";
  } else {
    d = t2s;
    tgt.push(o["id"])
    other_t = "source";
  }

  if (!d[o["id"]]) return;
  if (d[o["id"]].length==0) return;

  done[o["id"]] = true;

  for (var i=0; i < d[o["id"]].length; i++) {
    explore({"id":d[o["id"]][i], "type":other_t}, src, tgt, s2t, t2s, done);
  }

  return;
}

var rule_diff = function (prev,now)
{
  var diff = {};
  for (key in now) {
    if (prev[key] && now[key] != prev[key]) {
      diff[key] = now[key];
    }
    if (!prev[key]) {
      diff[key] = now[key];
    }
  }

  return diff;
}

var get_simplest_rules = function ()
{
  var s2t = [];
  var t2s = [];
  for (key in DE_connections) {
    var a = key.split("-");
    if (s2t.hasOwnProperty(a[0])) {
      s2t[parseInt(a[0])].push(parseInt(a[1]));
    } else {
      s2t[parseInt(a[0])] = [parseInt(a[1])];
    }
    if (t2s.hasOwnProperty(a[1])) {
      t2s[parseInt(a[1])].push(parseInt(a[0]));
    } else {
      t2s[parseInt(a[1])] = [parseInt(a[0])];
    }
  }

  var rules = [];
  var done = {};
  for (var i=0; i < DE_shapes.length; i++) {
    if (DE_shapes[i]["type_"] == "source") {
      var id = parseInt(DE_shapes[i]["id_"]);
      var src = [];
      var tgt = [];
      explore({"id":id,"type":"source"}, src, tgt, s2t, t2s, done);
      if (src.length >0 && tgt.length>0) {
        rules.push( {"src":src, "tgt":tgt } );
      }
    }
  }

  rs = {}
  for (r in rules) {
    var src = "", tgt = "";
    var prev=null
    for (var i=0; i< rules[r]["src"].length; i++) {
      if (prev!=null && prev < rules[r]["src"][i]-1) {
        src += "[X] ";
      }
      src += DE_shapes_by_id[rules[r]["src"][i]].pair[0].textContent+" ";
      if (rules[r]["src"][i]!=null)
        prev = rules[r]["src"][i];
    }
    src += "||| ";
    prev = null;
    for (var i=0; i< rules[r]["tgt"].length; i++) {
      if (!DE_shapes_by_id[rules[r]["tgt"][i]]) // unaligned source
        continue;
      if (prev && prev < rules[r]["tgt"][i]-1) {
        tgt += "[X] ";
      }
      tgt += DE_shapes_by_id[rules[r]["tgt"][i]].pair[0].textContent+" ";
      if (rules[r]["tgt"][i])
        prev = rules[r]["tgt"][i];
    }
    if (tgt.replace(/\|\|\|/g, "").trim() != "") {
      var id = rules[r]["tgt"][0];
      var b = false;
      if (DE_target_shapes[0]["id_"] == id) {
        b = true;
      }
      rs[rules[r]["src"]] = b+" ||| "+$.trim(src+tgt);
    }
  }

  return rs;
}

var id2idx = function (id) { // or grid_pos
  var i = 0;
  for (k in DE_target_shapes) {
    if (DE_target_shapes[k]["id_"] == id) {
      return i;
    }
    i++;
  }

  return -1;
}

var idx2id = function (idx) {
  return DE_target_shapes[idx]["id_"];
}

var amax = function (a) {
  var max = -9999999999999;
  for (k in a) {
    if (a[k] > max)
      max = a[k];
  }
  return max;
}

var $rules =[];
var get_simplest_rules1 = function ()
{
  var s2t = [];
  var t2s = [];
  for (key in DE_connections) {
    var a = key.split("-");
    if (s2t.hasOwnProperty(a[0])) {
      s2t[parseInt(a[0])].push(parseInt(a[1]));
    } else {
      s2t[parseInt(a[0])] = [parseInt(a[1])];
    }
    if (t2s.hasOwnProperty(a[1])) {
      t2s[parseInt(a[1])].push(parseInt(a[0]));
    } else {
      t2s[parseInt(a[1])] = [parseInt(a[0])];
    }
  }

  var rules = [];
  var done = {};
  for (var i=0; i < DE_shapes.length; i++) {
    if (DE_shapes[i]["type_"] == "source") {
      var id = parseInt(DE_shapes[i]["id_"]);
      var src = [];
      var tgt = [];
      explore({"id":id,"type":"source"}, src, tgt, s2t, t2s, done);
      if (src.length >0 && tgt.length>0) {
        tgt.sort(function(a,b) { return id2idx(a) > id2idx(b) });
        rules.push( {"src":src, "tgt":tgt } );
      }
    }
  }

  for (var z=0; z<rules.length; z++) {
    var src_gaps = [];
    var tgt_gaps = [];
    var r = rules[z];
    var prev = null;

    for (var j=0; j<r.src.length; j++) {
      if (prev!=null && prev<(r.src[j]-1)) { // id == index == pos
        var a = [];
        for (var k=prev+1; k<r.src[j]; k++) {
          a.push(k);
        }
        src_gaps.push(a);
      }
      prev = r.src[j];
    }

    prev = null;
    for (var j=0; j<r.tgt.length; j++) {
      if (prev!=null && prev<((id2idx(r.tgt[j]))-1)) {
        var a = [];
        for (var k=prev+1; k<id2idx(r.tgt[j]); k++) {
          a.push(k);
        }
        tgt_gaps.push(a);
      }
      prev = id2idx(r.tgt[j]);
    }

    r["src_gaps"] = src_gaps;
    r["tgt_gaps"] = tgt_gaps;
    r["src_gaps_pos"] = []; // 0 before, 1 after
    src_gaps_covered = [];
    var tgt_indexes = [];
    var invalid = false;
    for (k in r.tgt_gaps) { // for each target gap
      var g = r.tgt_gaps[k]; // current gap
      var ga = g.map(function(i) { // these are the aligned sources to this gap
        try {
          return t2s[idx2id(i)][0];
        } catch(e) {
          return null;
        }
      });
      var index = -1; // behind or before
      var b = false;
      for (var l=ga.length-1; l>=0; l--) { // take the last one / or should I?
        for (m in r.src_gaps) {
          if (r.src_gaps[m].find(function(i) { return i==ga[l] })) {
            index = m;
            src_gaps_covered.push(m);
            b = true;
            break;
          }
          if (b) break;
        }
      }

      if (index == -1) { // not found within
        // try to find outside
        var x = null;
        for (var j=ga.length-1; j>=0; j--) { // first (from the back) aligned
          if (ga[j]) {
            x = ga[j];
            break;
          }
        }
        if (x == null) {
          if (r.src_gaps.length == 1 && r.tgt_gaps.length == 1) {
            index = 0;
            src_gaps_covered.push(0);
          } else {
            invalid = true;
          }
        } else {
          if (x < r.src[0]) { // before
            r.src_gaps.unshift([x]);
            tgt_indexes = tgt_indexes.map(function(i) { return i+1 });
            index = 0;
            r["src_gaps_pos"].push(0);
            src_gaps_covered.push(-1); // doesn't matter
          } else if (x > r.src[r.src.length-1]) { // after
            r.src_gaps.push([x]);
            index = Math.max(0,amax(tgt_indexes)+1);
            r["src_gaps_pos"].push(1);
            src_gaps_covered.push(-1); // doesn't matter
          } else {
            invalid = true;
          }
        }
      }
      tgt_indexes.push(parseInt(index));
    }

    r["tgt_gaps_pos"] = [];
    if (r.src_gaps.length > src_gaps_covered.length) {
      for (k in r.src_gaps) {
        if (!src_gaps_covered.find(function(i){return i==k;})) { // not covered
          try {
            for (var l=r.src_gaps[k].length-1; l>=0; l--) {
              if (s2t[r.src_gaps[k][l]]!=null) {
                if (s2t[r.src_gaps[k][l]] > id2idx(r.tgt[0])) { // before
                  r["tgt_gaps_pos"].push(0);
                } else if(s2t[r.src_gaps[k][l]] < id2idx(r.tgt[r.tgt.length-1])) { //after
                  //alert("!!");
                  r["tgt_gaps_pos"].push(1);
                } else {
                }
                break;
              }
            }
          } catch(e) {
          }
        }
      }
    }
    r["tgt_indexes"] = tgt_indexes;
    r["invalid"] = invalid;
  }

  for (var z=0; z<rules.length; z++) { // FIXME why here?
    r = rules[z];
    if (r.tgt_indexes.length!=r.tgt_gaps.length || r.tgt_indexes.length!=r.src_gaps.length) {
      r.invalid = true;
    }
  }

  rs = {}
  for (r in rules) {
    if (r.invalid) {
      //alert(r);
      continue;
    }
    var src = "", tgt = "";
    var prev=null
    var src_idx = 1;
    var src_gaps_count = 0;
    for (var i=0; i< rules[r]["src"].length; i++) {
      if (prev!=null && prev < rules[r]["src"][i]-1) { // work, because id==idx
        src += "[X,"+src_idx+"] ";
        src_idx++;
      }
      src += DE_shapes_by_id[rules[r]["src"][i]].pair[0].textContent+" ";
      if (rules[r]["src"][i]!=null)
        prev = rules[r]["src"][i];
    }
    if ((src_idx-1) < rules[r]["src_gaps_pos"].length) {
      for (q in rules[r]["src_gaps_pos"]) {
        if (rules[r]["src_gaps_pos"][q] == 0) { // before
          var re=/\[X,(\d)\]/g;
          do { m = re.exec(src); if (m) { src[m.index+3] = parseInt(m[1])+1 }; } while (m);
          src = "[X,1] "+$.trim(src);
          src_gaps_covered.push(-1);
        } else { // after
          var re=/\[X,(\d)\]/g;
          var last = 0;
          do { m = re.exec(src); if (m) { last = parseInt(m[1]) }; } while (m);
          src = $.trim(src);
          src += " [X,"+(last+1)+"]";
          src_gaps_covered.push(-1);
        }
      }
    }
    src += "||| ";
    prev = null;
    var tgt_idx_idx = 0;
    for (var i=0; i< rules[r]["tgt"].length; i++) {
      if (!DE_shapes_by_id[rules[r]["tgt"][i]]) { // unaligned source
        continue;
      }
      if (prev!=null && prev < id2idx(rules[r]["tgt"][i])-1) {
        tgt += "[X,"+(rules[r]["tgt_indexes"][tgt_idx_idx]+1)+"] " ;
        tgt_idx_idx++;
      }
      tgt += DE_shapes_by_id[rules[r]["tgt"][i]].pair[0].textContent+" ";
      if (rules[r]["tgt"][i]) {
        prev = id2idx(rules[r]["tgt"][i]);
      }
    }
    for (k in rules[r]["tgt_gaps_pos"]) {
      if (rules[r]["tgt_gaps_pos"][k] == 0) { // before
        var re=/\[X,(\d)\]/g;
        do { m = re.exec(tgt); if (m) { tgt[m.index+3] = parseInt(m[1])+1 }; } while (m);
        tgt = "[X,1] "+$.trim(tgt);
      } else { // after
        var re=/\[X,(\d)\]/g;
        var last = 0;
        do { m = re.exec(tgt); if (m) { last = parseInt(m[1]) }; } while (m);
        tgt = $.trim(tgt);
        tgt += " [X,"+(last+1)+"]";
      }
    }
    if (tgt.replace(/\|\|\|/g, "").trim() != "") {
      var id = rules[r]["tgt"][0];
      var b = false;
      if (DE_target_shapes[0]["id_"] == id) {
        b = true;
      }
      var accept = true;
      var x = src.match(/\[X,\d\]/g);
      var y = tgt.match(/\[X,\d\]/g);
      if (x && y) {
        accept = x.length==y.length;
        var srci = src.match(/\[X,(\d)\]/g).map(function(i){return parseInt(i.split(",")[1].replace("]",""))}).sort()
        var tgti = tgt.match(/\[X,(\d)\]/g).map(function(i){return parseInt(i.split(",")[1].replace("]",""))}).sort()
        var prev = null;
        var uniq = true;
        for (k in srci) {
          if (prev!=null && prev==srci[k]) {
            uniq = false;
            break;
          }
          prev = srci[k];
        }
        prev = null
        for (k in tgti) {
          if (prev!=null && prev==tgti[k]) {
            uniq = false;
            break;
          }
          prev = tgti[k];
        }
        accept = accept && uniq;
        var same = true;
        if (srci.length == tgti.length) {
          for (k in srci) {
            if (srci[k] != tgti[k]) {
              same = false;
              break;
            }
          }
        }

        accept = accept && same;

      } else if (x && !y || !x && y) {
        accept = false
      }

      if (accept) {
        rs[rules[r]["src"]] = b+" ||| "+$.trim(src+tgt);
      } else {
        //alert(src+tgt+" "+rules[r]["tgt_gaps"].length+" "+src_gaps_covered.length+" --- "+String(x.length==y.length) + " " + String(uniq) + " " + String(same));
      }
    }
  }

  $rules = rules;

  return rs;
}

