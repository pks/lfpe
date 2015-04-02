<html>
<head>
  <meta charset="utf-8" />
  <title>Post-editing application</title>
  <script src="lfpe.js"></script>
  <link rel="stylesheet" type="text/css" href="lfpe.css" />
</head>

<body onload="Next()">

<div>
  <textarea id="src" name="source" cols="1" rows="1" readonly></textarea>
</div>

<div>
  <textarea id="trgt" name="target" cols="1" rows="1"></textarea>
</div>

<p>
  <button id="next" type="button" onclick="Next()">Next</button>
</p>

<p id="translating_status">
  <strong>translating</strong> <img src="img/ajax-loader-large.gif" width="20px" />
</p>

</body>
</html>

