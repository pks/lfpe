var data,
    ui_type;


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

