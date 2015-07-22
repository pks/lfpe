<html>
<head>
  <meta charset="utf-8" />
  <title>Post-editing application (Session: #<?php echo $_GET["key"]; ?>)</title>
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

<!-- Buttons -->
<div>
  <button id="pause_button" type="button" onclick="pause()">Pause</button>
  <button id="next" type="button" onclick="Next()">Start/Continue</button>
  <span id="status"><strong>Working, please wait for next segment</strong> <img src="img/ajax-loader-large.gif" width="20px" /></span>
</div>
<!-- /Buttons -->

<!-- Session overview -->
<div id="overview_wrapper">
<strong>Session overview</strong>
<table id="overview">
<?php
$SESSION_DIR="/fast_scratch/simianer/lfpe/sessions";
$json = file_get_contents($SESSION_DIR."/".$_GET["key"]."/data.json");
$db = json_decode($json);

$class = "";
$i = 0;
foreach($db->raw_source_segments as $s) {
  if (in_array($i, $db->docs)) {
    $class = "doc_title";
  } else {
    $class = "";
  }
  $translation = "";
  if ($i <= $db->progress) {
    $translation = $db->post_edits_raw[$i];
  }
  echo "<tr class='".$class."' id='seg_".$i."'><td>".($i+1).".</td><td>".$s."</td><td class='seg_text' id='seg_".$i."_t'>".$translation."</td></tr>";
  $i += 1;
}
?>
</table>
</div>
<!-- /Session overview -->

<!-- Help -->
<button id="help_button" onclick="toggleDisplay(document.getElementById('help'));">Help</button> 
<div id="help" style="display:none">
<p>Press the 'Next' button to submit your post-edit and to request the next segment for translation.
Alternatively, just press enter when you finished the post-edit and the 'Target' text area is in focus. Warning: Past post-edits can not be altered. The session can be stopped at any time and continued later; However, if you have to pause your session, wait until the activity notification disappears and then press 'Pause', as we are collecting timing information. You may also just reload this site and re-request the next segment upon your return. Please only use <em>one</em> browser window at once. Going back to earlier examples is not possible, please take great care when interacting with the system.<br/>
The interface was only tested with Firefox 31.</p>
<p class="xtrasmall">Support: <a href="mailto://simianer@cl.uni-heidelberg.de">Mail</a></p>
<p class="xtrasmall">Session: #<?php echo $_GET["key"]; ?> | <a href="http://coltrane.cl.uni-heidelberg.de:<?php echo $db->port; ?>/debug" target="_blank">Debug</a></p>
</div>
<!-- /Help -->

<?php include("footer.php"); ?>

</body>
</html>

<!-- Data -->
<textarea style="display:none" id="key"><?php echo $_GET['key']; ?></textarea>
<textarea style="display:none" id="source"></textarea>
<textarea style="display:none" id="last_post_edit"></textarea>
<textarea style="display:none" id="current_seg_id">0</textarea>
<textarea style="display:none" id="paused">0</textarea>
<textarea style="display:none" id="oov_correct">0</textarea>
<textarea style="display:none" id="displayed_oov_hint">0</textarea>
<textarea style="display:none" id="port"><?php echo $db->port; ?></textarea>
<textarea style="display:none" id="init">0</textarea>
<!-- /Data -->

