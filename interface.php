<html>
<head>
  <meta charset="utf-8" />
  <title>Post-Editing Interface (Session: #<?php echo $_GET["key"]; ?>)</title>
  <link rel="stylesheet" type="text/css" href="static/main.css" />
  <script src="http://ajax.googleapis.com/ajax/libs/jquery/1.11.2/jquery.min.js" charset="utf-8"></script>
  <script src="js/common.js" charset="utf-8"></script>
  <script src="js/lfpe.js" charset="utf-8"></script>
  <script src="https://raw.githubusercontent.com/DmitryBaranovskiy/raphael/v2.1.2/raphael-min.js" type="text/javascript" charset="utf-8"></script>
  <!--<script src="https://raw.githubusercontent.com/marmelab/Raphael.InlineTextEditing/fd578f0eddd4172e6d9b3fde4cb67576cf546dc1/raphael.inline_text_editing.js" charset="utf-8"></script>-->
  <script src="js/derivation_editor/raphael.inline_text_editing.js" charset="utf-8"></script>
  <script src="js/derivation_editor/derivation-editor.js" charset="utf-8"></script>

</head>

<body>

<?php include("header.inc.php"); ?>

<!-- Derivation editor -->
<div id="derivation_editor">
  <div id="holder"><img style="margin:.4em" src="static/placeholder.png" /></div>
</div>
<!-- /Derivation editor-->

<!-- Source and target textboxes -->
<div id="textboxes">
  <table>
    <tr>
      <td align="right">Source:</td>
      <!--<td><textarea id="raw_source_textarea" name="source" cols="80" rows="1" disabled></textarea></td>-->
      <td id="raw_source_textarea"></td>
    </tr>
    <tr>
      <td align="right">Target:</td>
      <td><textarea id="target_textarea" name="target" cols="80" rows="1" onkeypress="catch_return(event);" disabled></textarea></td>
    </tr>
  </table>
</div>
<div id="oov_form">
  <p style="margin-bottom:0"><strong>Unknown words</strong><br />
  <span class="small">Please enter a translation for each source word, then click 'Next' or press return.<br />
Note that the source word may be distorted.</span>
</p>
<p><span style="text-decoration:underline;font-size:0.8em">Context:</span> <span id="oov_context"></span></p>
  <div id="oov_fields"></div>
</div>
<!-- /Source and target textboxes -->


<!-- Buttons -->
<div>
  <button id="pause_button" class='button' type="button" onclick="pause()">Pause</button>
  <button id="reset_button" class='button' type="button" onclick="DE_init()">Reset</button>
  <button id="next" type="button" class='button' onclick="Next();">Start/Continue</button>
  <span id="status"><strong>Working, please wait for next translation</strong> <img src="static/ajax-loader-large.gif" width="20px" /></span>
</div>
<!-- /Buttons -->

<!-- Debug -->
<div id="debug"></div>
<!-- /Debug -->

<!-- Session overview -->
<div id="overview_wrapper">
<p style="margin:.5em;margin-bottom:.25em"><strong>Session overview</strong></p>
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
  if ($i < $db->progress) {
    $translation = $db->post_edits_display[$i];
  }
  echo "<tr class='".$class."' id='seg_".$i."'><td class='num'>".($i+1).".</td><td>".$s."</td><td class='seg_text' id='seg_".$i."_t'>".$translation."</td></tr>";
  $i += 1;
}
?>
</table>
</div>
<!-- /Session overview -->

<!-- Help -->
<button id="help_button" onclick="$('#help').toggle('blind')">Help</button>
<div id="help" style="display:none">
<?php include("help.inc.php"); ?>
<p class="xtrasmall">Support: <a href="mailto://simianer@cl.uni-heidelberg.de">Mail</a></p>
<p class="xtrasmall">Session: #<?php echo $_GET["key"]; ?> | <a href="http://coltrane.cl.uni-heidelberg.de:<?php echo $db->port; ?>/debug" target="_blank">Debug</a></p>
</div>
<!-- /Help -->

<p class="small" style="text-align:right"><a href="#">^</a></p>

<?php include("footer.inc.php"); ?>

</body>
</html>

<!-- Data -->
<textarea style="display:none" id="key"><?php echo $_GET['key']; ?></textarea>
<textarea style="display:none" id="source"></textarea>
<textarea style="display:none" id="last_post_edit"></textarea>
<textarea style="display:none" id="current_seg_id">0</textarea>
<textarea style="display:none" id="paused">0</textarea>
<textarea style="display:none" id="oov_correct">0</textarea>
<textarea style="display:none" id="oov_num_items">0</textarea>
<textarea style="display:none" id="displayed_oov_hint">0</textarea>
<textarea style="display:none" id="port"><?php echo $db->port; ?></textarea>
<textarea style="display:none" id="init">0</textarea>
<textarea style="display:none" id="ui_type"><?php echo $_GET["ui_type"]; ?></textarea>
<textarea style="display:none" id="data"></textarea>
<!-- /Data -->

