<html>
<head>
  <meta charset="utf-8" />
  <title>Post-editing application (key: <?php echo $_GET["key"]; ?></title>
  <script src="lfpe.js"></script>
  <link rel="stylesheet" type="text/css" href="lfpe.css" />
</head>

<body onload="">

<!-- Wrapper -->
<div id="wrapper">

<!-- Header -->
<div id="header">
  <img id="uni" src="img/logo_neu_204x107.jpg" />
  <img id="cl"  src="img/institut_cl.png" />
</div>
<!-- /Header -->

<!-- Source and target -->
<table>
<tr>
  <td align="right">Source:</td>
  <td><textarea id="raw_source_textarea" name="source" cols="80" rows="1" disabled></textarea></td>
</tr>
<tr>
  <td align="right">Target:</td>
  <td><textarea id="target_textarea" name="target" cols="80" rows="1" onkeypress="catch_return(event)"></textarea></td>
</tr>
</table>
<!-- /Source and target -->

<!-- Next button -->
<div>
  <button id="pause_button" type="button" onclick="pause()">Pause</button>
  <button id="next" type="button" onclick="Next()">Start/Continue</button>
  <span id="status"><strong>Working</strong> <img src="img/ajax-loader-large.gif" width="20px" /></span>
</div>
<!-- /Next button -->

<!-- Document overview -->
<div>
<strong>Document overview</strong>
<table id="overview">
<?php
$j = file_get_contents("/fast_scratch/simianer/lfpe/example_session/".$_GET["key"].".json"); # FIXME: from database
$a = json_decode($j);
$i = 0;
foreach($a->raw_source_segments as $s) {
  if ($i <= $a->progress) {
    echo "<tr id='seg_".$i."'><td>".($i+1).".</td><td>".$s."</td><td class='seg_text' id='seg_".$i."_t'>".$a->post_edits_raw[$i]."</td></tr>";
  } else {
    echo "<tr id='seg_".$i."'><td>".($i+1).".</td><td>".$s."</td><td class='seg_text' id='seg_".$i."_t'></td></tr>";
  }
  $i += 1;
}
?>
</table>
</div>
<!-- /Document overview -->

<!-- Help -->
<p id="help">
<strong>Help</strong><br />
Press the 'Next' to submit your post-edit and to request the next segment to translate
(or just press enter when the 'Target' textarea is in focus).
</p>
<!-- /Help -->

<!-- Footer -->
<p id="footer">
  &copy;2015 Heidelberg University/Institute for Computational Linguistics
</p>
<!-- /Footer -->

</div>
<!-- /Wrapper -->

<!-- Data -->
<textarea style="display:none" id="key"><?php echo $_GET['key']; ?></textarea>
<textarea style="display:none" id="source"></textarea>
<textarea style="display:none" id="current_seg_id">0</textarea>
<textarea style="display:none" id="paused">0</textarea>
<!-- /Data -->

</body>
</html>

