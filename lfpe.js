/*
 * Timer
 *
 */
var Timer = {
  start_t: 0,
  pause_start_t: 0,
  pause_acc_t: 0,
  paused: false,

  start: function() {
    this.start_t = Date.now();
    this.pause_start_t = 0;
    this.pause_acc_t = 0;
    this.paused = false;
  },
  pause: function() {
    this.paused = true;
    this.pause_start_t = Date.now();
  },
  unpause: function() {
    this.paused = false;
    this.pause_acc_t += Date.now()-this.pause_start_t;
    this.pause_start_t = 0;
  },
  get: function() {
    return (Date.now()-this.start_t)-this.pause_acc_t;
  }
}

/*
 * init site
 *
 */
function init()
{
  document.getElementById("target_textarea").value     = "";
  document.getElementById("raw_source_textarea").value = "";
  document.getElementById("source").value              = "";
  document.getElementById("current_seg_id").value      = "";
  document.getElementById("paused").value              = "";
  document.getElementById("oov_correct").value         = false;
  document.getElementById("displayed_oov_hint").value  = false;
          document.getElementById("next").removeAttribute("disabled");
  document.getElementById("pause_button").removeAttribute("disabled");

  return false;
}

/*
 * cross-site request
 *
 */
function CreateCORSRequest(method, url)
{
  var xhr = new XMLHttpRequest();
  if ("withCredentials" in xhr) {
    xhr.open(method, url, true);
  } else {
    xhr = null;
  }

  return xhr;
}

/*
 * no newline on return in textarea
 *
 */
function catch_return(e)
{
  if (e.keyCode == 13) {
    e.preventDefault();
    Next();
  }

  return false;
}

/*
 * pause/unpause timer
 *
 */
function pause()
{
  var paused      = document.getElementById("paused");
  var button      = document.getElementById("pause_button");
  var next_button = document.getElementById("next");
  if (paused.value == 0) {
    button.innerHTML = "Unpause";
    paused.value = 1;
    next.setAttribute("disabled", "disabled");
    Timer.pause();
  } else {
    button.innerHTML = "Pause";
    paused.value = 0;
    next.removeAttribute("disabled");
    Timer.unpause();
  }
}

/*
 * next button
 *
 */
function Next()
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

  // disable button and textarea
           button.setAttribute("disabled", "disabled");
     pause_button.setAttribute("disabled", "disabled");
  target_textarea.setAttribute("disabled", "disabled");

  // get metadata stored in DOM
  var port     = document.getElementById("port").value;
  var base_url = "http://coltrane.cl.uni-heidelberg.de:"+port;
  var key      = document.getElementById("key").value;

  next_url = base_url+"/next?key="+key;

  var post_edit = target_textarea.value;
  if (oov_correct.value=="false" && post_edit != "") {
    // compose request
    next_url += "&example="+source.value+" %7C%7C%7C "+post_edit+"&duration="+Timer.get();
    // update document overview
    document.getElementById("seg_"+(current_seg_id.value)+"_t").innerHTML=post_edit;
  } else if (oov_correct.value=="true" && post_edit != "") {
    next_url += "&correct="+raw_source_textarea.value+" %7C%7C%7C "+post_edit
  } else {
    if (source.value != "") {
      alert("Error: 1"); // FIXME: do something reasonable
    }
  }

  // show 'working' message
  status.style.display = "block";

  // build request
  var xhr = CreateCORSRequest('get', next_url);
  if (!xhr) {
    alert("Error: 2"); // FIXME: do something reasonable
  }

  // 'next' request's callbacks
  xhr.onload = function() {
     // translation system is currently handling a request
     // FIXME: maybe poll server for result?
    if (xhr.responseText == "locked") {
      alert("Translation system is locked, try again in a moment (reload page and click 'Start/Continue' again).");
      status.style.display = "none";

      return;
    }
    var x = xhr.responseText.split("\t");
    if (x == "fi") { // done -> hide/disable functional elements
      raw_source_textarea.style.display = "none";
      target_textarea.style.display     = "none";
      status.style.display              = "none";
      button.innerHTML                  = "Session finished, thank you!";
            button.setAttribute("disabled", "disabled");
      pause_button.setAttribute("disabled", "disabled");
      document.getElementById("seg_"+current_seg_id.value).className = "";
    } else {
      // got response: OOV\tseg id\ttoken_1\ttoken_2\t...
      //               0    1       2        3        ...
      if (x[0] == "OOV") {
        var s = "";
        for (var i=2; i < x.length; i++) {
          s += x[i].substr(1,x[i].length-2);
          if (i+1 < x.length) {
            s += "; ";
          }
          raw_source_textarea.value = s;
        }
        // update interface
        status.style.display = "none";
        button.innerHTML     = "Correct";
                 button.removeAttribute("disabled");
        target_textarea.removeAttribute("disabled", "disabled");
           pause_button.removeAttribute("disabled", "disabled");
        target_textarea.value          = "";
        target_textarea.focus();
        target_textarea.selectionStart = 0;
        target_textarea.selectionEnd   = 0;
        oov_correct.value              = true;
        var id                         = x[1];
        document.getElementById("seg_"+id).className = "bold";
        if (id > 0) {
          document.getElementById("seg_"+(id-1)).className = "";
        }
        if (document.getElementById("displayed_oov_hint").value == "false") {
          alert("Please translate the following words (separated by semicolons) to enable translation of the next sentence. Use proper casing.");
          document.getElementById("displayed_oov_hint").value = true;
        }

        return;
      }
      // got response: seg id\tsource\ttranslation\traw source
      //               0       1       2            3
      var id          = x[0];
      var src         = x[1];
      var translation = x[2];
      var raw_source  = x[3];

      // update interface
      oov_correct.value         = false;
      status.style.display      = "none";
      target_textarea.value     = translation;
      raw_source_textarea.value = raw_source;
      button.innerHTML          = "Next";
               button.removeAttribute("disabled");
      target_textarea.removeAttribute("disabled", "disabled");
         pause_button.removeAttribute("disabled", "disabled");
      document.getElementById("seg_"+id).className = "bold";
      if (x[0] > 0) {
        document.getElementById("seg_"+(id-1)).className = "";
      }
      target_textarea.rows     = Math.round(translation.length/80)+1;
      raw_source_textarea.rows = Math.round(raw_source.length/80)+1;
      target_textarea.focus();
      target_textarea.selectionStart = 0;
      target_textarea.selectionEnd   = 0;

      // remember aux data in DOM
      current_seg_id.value = id;
      source.value         = src;

      // confirm to server
      var xhr_confirm = CreateCORSRequest('get', base_url+"/confirm");
      xhr_confirm.send(); // FIXME: handle errors

      Timer.start();
    }
  };

  xhr.onerror = function() {
    // FIXME: do something reasonable
  };

  xhr.send(); // send 'next' request

  return;
}

