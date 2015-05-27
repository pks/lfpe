<html>
<head>
  <meta charset="utf-8" />
  <title>Post-editing application</title>
  <script src="lfpe.js"></script>
  <link rel="stylesheet" type="text/css" href="lfpe.css" />
</head>

<body onload="Next()">

<div id="wrapper">

<div id="header">
<img src="img/logo_neu_204x107.jpg" />
<img id="cl" src="img/institut_cl.png" />
</div>

<table>
<tr>
  <td align="right">Source:</td>
  <td><textarea id="src" name="source" cols="80" rows="1" readonly></textarea></td>
</tr>
<tr>
  <td align="right">Target:</td>
  <td><textarea id="trgt" name="target" cols="80" rows="1" onkeypress="submit(event)"></textarea></td>
</tr>
</table>

<p>
  <button id="next" type="button" onclick="Next()">Next</button>
</p>

<p id="desc">
<strong>Help</strong><br />
Press the 'Next' to submit your post-edit and to request the next segment to translate
(or just press enter when the 'Target' textarea is in focus).
</p>

<p id="footer">
  &copy;2015 Heidelberg University/Institute for Computational Linguistics
</p>

</div>


<p id="translating_status">
  <strong>Translating</strong> <img src="img/ajax-loader-large.gif" width="20px" />
</p>


<textarea style="display:none" id="src_pp"></textarea>

</body>
</html>

