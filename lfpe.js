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
  document.getElementById("init").value                = "";
  document.getElementById("target_textarea").setAttribute("disabled", "disabled");
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
 * check oov correction input
 *
 */
function check_oov_correction()
{
  var need = trim(document.getElementById("raw_source_textarea").value).split(";").length;
  var a = trim(document.getElementById("target_textarea").value).split(";");
  a = a.filter(function(i){ return i!=""; })

  return need==a.length;
}

/*
 * pause/unpause timer
 *
 */
function pause()
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
 * hacky way to remove class from node
 *
 */
function removeClass(node, className)
{
  node.className =
    node.className.replace(" "+className,'');
  node.className =
    node.className.replace(" "+className,''); // ???

  return false;
}

/*
 *
 *
 */
function toggleDisplay(node)
{
  if (node.style.display=='none') {
    node.style.display = 'block';
  } else {
    node.style.display = 'none';
  }

  return false;
}

/*
 * trim string
 *
 */
function trim(s)
{
  return s.replace(/^\s+|\s+$/g, '');
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
  var last_post_edit      = document.getElementById("last_post_edit");

  // disable button and textarea
           button.setAttribute("disabled", "disabled");
     pause_button.setAttribute("disabled", "disabled");
  target_textarea.setAttribute("disabled", "disabled");

  // get metadata stored in DOM
  var port     = document.getElementById("port").value;
  var base_url = "http://coltrane.cl.uni-heidelberg.de:"+port;
  var key      = document.getElementById("key").value;

  next_url = base_url+"/next?key="+key;

  var post_edit = trim(target_textarea.value);
  if (oov_correct.value=="false" && post_edit != "") {
      // compose request
      next_url += "&example="+encodeURIComponent(source.value)+"%20%7C%7C%7C%20"+encodeURIComponent(post_edit)+"&duration="+Timer.get();
      // no change?
      if (post_edit == last_post_edit.value) {
        next_url += "&nochange=1";
      }
      // update document overview
      document.getElementById("seg_"+(current_seg_id.value)+"_t").innerHTML=post_edit;
  } else if (oov_correct.value=="true") {
    if (!check_oov_correction()) {
      alert("Please provide translations for each word in the 'Source' text area, separated by ';'.");
      target_textarea.removeAttribute("disabled", "disabled");
         pause_button.removeAttribute("disabled", "disabled");
               button.removeAttribute("disabled", "disabled");
      return;
    }
    next_url += "&correct="+encodeURIComponent(raw_source_textarea.value)+"%20%7C%7C%7C%20"+encodeURIComponent(post_edit)
  } else {
    if (source.value != "") {
      alert("Please provide a post-edit.");
      target_textarea.removeAttribute("disabled", "disabled");
         pause_button.removeAttribute("disabled", "disabled");
               button.removeAttribute("disabled", "disabled");
      return;
    }
  }

  // show 'working' message
  status.style.display = "block";

  // confirm to server
  if (document.getElementById("init").value != "") {
    var xhr_confirm = CreateCORSRequest('get', base_url+"/confirm");
    xhr_confirm.send(); // FIXME: handle errors
  }

  // build request
  var xhr = CreateCORSRequest('get', next_url);
  if (!xhr) {
    alert("Error: 2"); // FIXME: do something reasonable
  }

  // 'next' request's callbacks
  xhr.onload = function() {
    document.getElementById("init").value = 1; // for pause()
     // translation system is currently handling a request
     // FIXME: maybe poll server for result?
    if (xhr.responseText == "locked") {
      alert("Translation system is locked, try again in a moment (reload page and click 'Start/Continue' again).");
      status.style.display = "none";

      return;
    }
    var x = xhr.responseText.split("\t");
    if (x == "fi") { // done -> hide/disable functional elements
      raw_source_textarea.setAttribute("disabled", "disabled");
          target_textarea.setAttribute("disabled", "disabled");
      status.style.display              = "none";
      button.innerHTML                  = "Session finished, thank you!";
            button.setAttribute("disabled", "disabled");
      pause_button.setAttribute("disabled", "disabled");
      removeClass(document.getElementById("seg_"+current_seg_id.value), "bold");
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
        document.getElementById("seg_"+id).className += " bold";
        if (id > 0) {
          removeClass(document.getElementById("seg_"+(id-1)), "bold");
        }
        if (document.getElementById("displayed_oov_hint").value == "false") {
          alert("Please translate the following words (separated by semicolons) to enable translation of the next sentence. Source words are always in lower case. Use correct casing for suggested translation.");
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
      document.getElementById("seg_"+id).className += " bold";
      if (id > 0) {
        removeClass(document.getElementById("seg_"+(id-1)), "bold");
      }
      target_textarea.rows     = Math.round(translation.length/80)+1;
      raw_source_textarea.rows = Math.round(raw_source.length/80)+1;
      target_textarea.focus();
      target_textarea.selectionStart = 0;
      target_textarea.selectionEnd   = 0;

      // remember aux data in DOM
      current_seg_id.value = id;
      source.value         = src;
      last_post_edit.value = translation;

      // confirm to server
      //var xhr_confirm = CreateCORSRequest('get', base_url+"/confirm");
      //xhr_confirm.send(); // FIXME: handle errors

      Timer.start();
    }
  };

  xhr.onerror = function() {
    // FIXME: do something reasonable
  };

  xhr.send(); // send 'next' request

  return;
}

