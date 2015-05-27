function CreateCORSRequest(method, url) {
  var xhr = new XMLHttpRequest();
  if ("withCredentials" in xhr) {
    // XHR for Chrome/Firefox/Opera/Safari.
    xhr.open(method, url, true);
  } else if (typeof XDomainRequest != "undefined") {
    // XDomainRequest for IE.
    xhr = new XDomainRequest();
    xhr.open(method, url);
  } else {
    // CORS not supported.
    xhr = null;
  }
  return xhr;
}

function submit(e) {
  if (e.keyCode == 13) {
    e.preventDefault();
    Next();
  }

  return false;
}

function Next()
{
  url = "http://coltrane.cl.uni-heidelberg.de:60666/next";
  var pe = document.getElementById("trgt").value;
  if (pe != "") {
    var src = document.getElementById("src_pp").value;
    url += "?example="+src+" %7C%7C%7C "+pe;
  }
  document.getElementById("translating_status").style.display = "block";
  var xhr = CreateCORSRequest('get', url);
  if (!xhr) {
    alert('CORS not supported');
    return;
  }

  xhr.onload = function() {
    var x = xhr.responseText.split("\t");
    if (x == "fi") {
      document.getElementById("src").style.display = "none";
      document.getElementById("trgt").style.display = "none";
      document.getElementById("translating_status").style.display = "none";
      document.getElementById("next").innerHTML = "Thank you!";
      document.getElementById("next").disabled = true;
    } else {
      document.getElementById("src_pp").value = x[0];
      document.getElementById("src").value = x[2];
      document.getElementById("src").rows = Math.round(x[2].length/80)+1;
      var firstLetter = x[1][0].toUpperCase();
      var rest = x[1].substring(1);
      var t = firstLetter + rest;
      document.getElementById("trgt").value = t;
      document.getElementById("trgt").rows = Math.round(x[1].length/80)+1;
      document.getElementById("translating_status").style.display = "none";
      document.getElementById("trgt").focus();
      document.getElementById("trgt").selectionStart = 0;
      document.getElementById("trgt").selectionEnd = 0;
    }
  };

  xhr.onerror = function() {
    alert('Error');
  };

  xhr.send();
}

