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
function toggleDisplay(id)
{
  node = $(id);
  if (node.style.display=='none') {
    node.fadeIn();
  } else {
    node.fadeOut();
  }

  return false;
}

/*
 * trim string
 *
 */
function trim(s)
{
  return s.replace(/(\||\n|\t)/g, " ").replace(/^\s+|\s+$/g, '').replace(/\s+/g, " ");
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

