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

function Next(url)
{
  url = "http://localhost:31337/next";
  var pe = document.getElementById("trgt").value;
  if (pe != "") {
    var src = document.getElementById("src").value;
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
      document.getElementById("src").value = x[0];
      document.getElementById("src").cols = x[0].length;
      document.getElementById("trgt").value = x[1];
      document.getElementById("trgt").cols = x[1].length;
      document.getElementById("translating_status").style.display = "none";
    }
  };

  xhr.onerror = function() {
    alert('Error');
  };

  xhr.send();
}

