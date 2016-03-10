<html>
<head>
  <meta charset="utf-8" />
  <title>Post-Editing Interface (Session: #<?php echo $_GET["key"]; ?>)</title>
  <link rel="stylesheet" type="text/css" href="static/main.css" />
  <script src="js/jquery.min.js"                                    type="text/javascript" charset="utf-8"></script>
  <script src="js/interface.js"                                     type="text/javascript" charset="utf-8"></script>
  <script src="js/raphael-min.js"                                   type="text/javascript" charset="utf-8"></script>
  <script src="js/derivation_editor/raphael.inline_text_editing.js" type="text/javascript" charset="utf-8"></script>
  <script src="js/derivation_editor/derivation-editor.js"           type="text/javascript" charset="utf-8"></script>
  <script src="js/jquery.scrollTo.min.js"                           type="text/javascript" charset="utf-8"></script>
</head>

<body>

<?php include("inc/db.inc.php"); ?>

<?php include("inc/header.inc.php"); ?>

<!-- Derivation editor -->
<div id="derivation_editor">
  <div id="holder" style="width:100px; overflow-x:scroll"></div>
</div>
<!-- /Derivation editor-->

<!-- Source and target textboxes -->
<div id="textboxes">
  <table>
    <tr>
      <td align="right">Source:</td>
      <td id="raw_source_textarea"></td>
    </tr>
    <tr>
      <td align="right">Target:</td>
      <td>
        <textarea id="target_textarea" name="target" cols="80" rows="1" onkeypress="catch_return(event);" disabled></textarea>
      </td>
    </tr>
  </table>
</div>
<div id="oov_form">
  <p><strong>Unknown words:</strong>
  Please enter a translation for each source word, then click 'Next' or simply press return.<br />
Note that the source word may be distorted.
</p>
<p><strong>Context:</strong> <span id="oov_context"></span></p>
  <div id="oov_fields"></div>
</div>
<!-- /Source and target textboxes -->

<!-- Buttons -->
<div>
  <button id="help_button" class="button" onclick="$('#help').toggle('blind')">Help</button>
  <button id="pause_button" class='button' type="button" onclick="pause()">Pause</button>
  <button id="reset_button" class='button' type="button" onclick="DE_init()">Reset</button>
  <button id="next" type="button" class='button' onclick="next();">Start/Continue</button>
  <span id="status"><strong>Working: <span id="status_detail">...</span></strong> <img src="static/ajax-loader-large.gif" width="20px" /></span>
</div>
<!-- /Buttons -->

<!-- Help -->
<div id="help">
  <?php include("inc/help.inc.php"); ?>
  <p class="tiny">
    Support: <a href="mailto://simianer@cl.uni-heidelberg.de">Mail</a>
  </p>
  <p class="tiny">Session: <?php echo $_GET["key"]; ?> |
    <a href="http://postedit.cl.uni-heidelberg.de:<?php echo $db->port; ?>/debug" target="_blank">Debug</a>
  </p>
</div>
<!-- /Help -->


<!-- Debug -->
<div id="debug"></div>
<!-- /Debug -->

<!-- Session overview -->
<div id="overview_wrapper">
<p id="overview_header">Session overview</p>
  <table id="overview">
    <?php include("inc/session-overview.inc.php"); ?>
  </table>
</div>
<!-- /Session overview -->

<?php include("inc/footer.inc.php"); ?>

</body>
</html>

<!-- Data -->
<textarea style="display:none" id="key"               ><?php echo $_GET['key']; ?></textarea>
<textarea style="display:none" id="source"            ></textarea>
<textarea style="display:none" id="last_post_edit"    ></textarea>
<textarea style="display:none" id="current_seg_id"    ><?php echo $db->progress; ?></textarea>
<textarea style="display:none" id="paused"            >0</textarea>
<textarea style="display:none" id="oov_correct"       >0</textarea>
<textarea style="display:none" id="oov_num_items"     >0</textarea>
<textarea style="display:none" id="displayed_oov_hint">0</textarea>
<textarea style="display:none" id="port"              ><?php echo $db->port; ?></textarea>
<textarea style="display:none" id="init"              >0</textarea>
<textarea style="display:none" id="ui_type"           ><?php echo $_GET["ui_type"]; ?></textarea>
<textarea style="display:none" id="data"              ></textarea>
<textarea style="display:none" id="original_svg"      ></textarea>
<!-- /Data -->

