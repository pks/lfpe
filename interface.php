<html>
<head>
  <meta charset="utf-8" />
  <title>Post-editing application (key: <?php echo $_GET["key"]; ?></title>
  <script src="lfpe.js"></script>
  <link rel="stylesheet" type="text/css" href="lfpe.css" />
</head>

<body onload="init()">

<?php include("header.php"); ?>

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
<div id="overview_wrapper">
<strong>Document overview</strong>
<table id="overview">
<?php
$SESSION_DIR="/fast_scratch/simianer/lfpe/sessions";
$j = file_get_contents($SESSION_DIR."/".$_GET["key"]."/data.json");
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
<div id="help">
<strong>Help</strong><br />
<p>Press the 'Next' to submit your post-edit and to request the next segment to translate
(or just press enter when the 'Target' textarea is in focus). You can stop your session at any time and continue it later; The 'Pause'
button has currently no function. Please only use <em>one</em> browser window at once.<br/>
The interface was tested with Firefox 31.</p>
<p class="xtrasmall">Support: <a href="mailto://simianer &auml;t cl.uni-heidelberg.de">Mail</a></p>
<p class="xtrasmall">Session: #<?php echo $_GET["key"]; ?> | <a href="http://coltrane.cl.uni-heidelberg.de:<?php echo $a->port; ?>/debug" target="_blank">Debug</a></p>
</div>
<!-- /Help -->

<?php include("footer.php"); ?>

</body>
</html>

<!-- Data -->
<textarea style="display:none" id="key"><?php echo $_GET['key']; ?></textarea>
<textarea style="display:none" id="source"></textarea>
<textarea style="display:none" id="current_seg_id">0</textarea>
<textarea style="display:none" id="paused">0</textarea>
<textarea style="display:none" id="port"><?php echo $a->port; ?></textarea>
<!-- /Data -->

