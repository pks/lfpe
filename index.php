<html>
<head>
  <meta charset="utf-8" />
  <title>Post-Editing Interface</title>
  <script src="js/jquery.min.js" charset="utf-8"></script>
  <script type="text/javascript">
  
  </script>
  <link rel="stylesheet" type="text/css" href="static/main.css" />
</head>

<body>

<?php include("inc/header.inc.php"); ?>

<form method="get" action="interface.php">
  <strong>Please enter your session key:</strong>
  <input type="text" id="key" name="key" style="width:8em" />
  &nbsp;&nbsp;&nbsp;&nbsp;Session type:
  <select name="ui_type">
    <!--<option value="g">graphical</option>-->
    <option value="t">text</option>
</select>
&nbsp;&nbsp;&nbsp;
<input type="submit" value="Submit" />
</form>

<!--<div class="small" style="background:#eee;margin: 5em 0 5em 0;padding:.5em; max-width:25%">


<?php
//if ($_GET['manual']) {
echo "<p>Select session: ";
echo "<select class='small'>";

  $f = fopen("../sessions/sessions", "r");
  $a = array();
  while (($line = fgets($f)) !== false) {
    $x = explode("\t", $line, 4);
    $a[$x[3]] = $x[0];
  }
  fclose($f);

  asort($a);

  foreach ($a as $key => $val) {
    echo "<option value='".$val."' onclick=\"document.getElementById('key').value=this.value;\">Session ".$key."</option>";
  }
  echo "</select></p>";
//} else {
//  echo '<p style="padding:1em"><a style="font-size:1.2em;color:#000" href="pool.php">Assignment</a></p><p><a href="?manual=1">Manual</a>';
//}
?>
-->

<!--  <option value="g0_0_nomt" >#0 (from scratch)</option>
  <option value="g0_0_pe" onclick="document.getElementById('key').value=this.value;">#0 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_1_nomt" onclick="document.getElementById('key').value=this.value;">#1 (from scratch)</option>
  <option value="g0_1_pe" onclick="document.getElementById('key').value=this.value;">#1 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_2_nomt" onclick="document.getElementById('key').value=this.value;">#2 (from scratch)</option>
  <option value="g0_2_pe" onclick="document.getElementById('key').value=this.value;">#2 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_3_nomt" onclick="document.getElementById('key').value=this.value;">#3 (from scratch)</option>
  <option value="g0_3_pe" onclick="document.getElementById('key').value=this.value;">#3 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_4_nomt" onclick="document.getElementById('key').value=this.value;">#4 (from scratch)</option>
  <option value="g0_4_pe" onclick="document.getElementById('key').value=this.value;">#4 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_5_nomt" onclick="document.getElementById('key').value=this.value;">#5 (from scratch)</option>
  <option value="g0_5_pe" onclick="document.getElementById('key').value=this.value;">#5 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_6_nomt" onclick="document.getElementById('key').value=this.value;">#6 (from scratch)</option>
  <option value="g0_6_pe" onclick="document.getElementById('key').value=this.value;">#6 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_7_nomt" onclick="document.getElementById('key').value=this.value;">#7 (from scratch)</option>
  <option value="g0_7_pe" onclick="document.getElementById('key').value=this.value;">#7 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_8_nomt" onclick="document.getElementById('key').value=this.value;">#8 (from scratch)</option>
  <option value="g0_8_pe" onclick="document.getElementById('key').value=this.value;">#8 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_9_nomt" onclick="document.getElementById('key').value=this.value;">#9 (from scratch)</option>
  <option value="g0_9_pe" onclick="document.getElementById('key').value=this.value;">#9 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_10_nomt" onclick="document.getElementById('key').value=this.value;">#10 (from scratch)</option>
  <option value="g0_10_pe" onclick="document.getElementById('key').value=this.value;">#10 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_11_nomt" onclick="document.getElementById('key').value=this.value;">#11 (from scratch)</option>
  <option value="g0_11_pe" onclick="document.getElementById('key').value=this.value;">#11 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_12_nomt" onclick="document.getElementById('key').value=this.value;">#12 (from scratch)</option>
  <option value="g0_12_pe" onclick="document.getElementById('key').value=this.value;">#12 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_13_nomt" onclick="document.getElementById('key').value=this.value;">#13 (from scratch)</option>
  <option value="g0_13_pe" onclick="document.getElementById('key').value=this.value;">#13 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_14_nomt" onclick="document.getElementById('key').value=this.value;">#14 (from scratch)</option>
  <option value="g0_14_pe" onclick="document.getElementById('key').value=this.value;">#14 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_15_nomt" onclick="document.getElementById('key').value=this.value;">#15 (from scratch)</option>
  <option value="g0_15_pe" onclick="document.getElementById('key').value=this.value;">#15 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_16_nomt" onclick="document.getElementById('key').value=this.value;">#16 (from scratch)</option>
  <option value="g0_16_pe" onclick="document.getElementById('key').value=this.value;">#16 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_17_nomt" onclick="document.getElementById('key').value=this.value;">#17 (from scratch)</option>
  <option value="g0_17_pe" onclick="document.getElementById('key').value=this.value;">#17 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_18_nomt" onclick="document.getElementById('key').value=this.value;">#18 (from scratch)</option>
  <option value="g0_18_pe" onclick="document.getElementById('key').value=this.value;">#18 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_19_nomt" onclick="document.getElementById('key').value=this.value;">#19 (from scratch)</option>
  <option value="g0_19_pe" onclick="document.getElementById('key').value=this.value;">#19 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_20_nomt" onclick="document.getElementById('key').value=this.value;">#20 (from scratch)</option>
  <option value="g0_20_pe" onclick="document.getElementById('key').value=this.value;">#20 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_21_nomt" onclick="document.getElementById('key').value=this.value;">#21 (from scratch)</option>
  <option value="g0_21_pe" onclick="document.getElementById('key').value=this.value;">#21 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_22_nomt" onclick="document.getElementById('key').value=this.value;">#22 (from scratch)</option>
  <option value="g0_22_pe" onclick="document.getElementById('key').value=this.value;">#22 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_23_nomt" onclick="document.getElementById('key').value=this.value;">#23 (from scratch)</option>
  <option value="g0_23_pe" onclick="document.getElementById('key').value=this.value;">#23 (post-editing)</option>
<optgroup label="________________"></optgroup>
  <option value="g0_24_nomt" onclick="document.getElementById('key').value=this.value;">#24 (from scratch)</option>
  <option value="g0_24_pe" onclick="document.getElementById('key').value=this.value;">#24 (post-editing)</option>-->

<!--<optgroup label="________________________">
  <option value="product_de-en_toy_example" onclick="document.getElementById('key').value=this.value;">toy example</option>
</optgroup>-->

<!--<optgroup label="Session A">
  <option value="product_de-en_beta_test_A" onclick="document.getElementById('key').value=this.value;">de-en</option>
  <option value="product_en-de_beta_test_A" onclick="document.getElementById('key').value=this.value;">en-de</option>
  <option value="product_de-en_beta_test_1_A" onclick="document.getElementById('key').value=this.value;">A* de-en</option>
  <option value="product_en-de_beta_test_1_A" onclick="document.getElementById('key').value=this.value;">A* en-de</option>
</optgroup>

<optgroup label="Session B">
  <option value="product_de-en_beta_test_B" onclick="document.getElementById('key').value=this.value;">de-en</option>
  <option value="product_en-de_beta_test_B" onclick="document.getElementById('key').value=this.value;">en-de</option>
  <option value="product_de-en_beta_test_1_B" onclick="document.getElementById('key').value=this.value;">B* de-en</option>
  <option value="product_en-de_beta_test_1_B" onclick="document.getElementById('key').value=this.value;">B* en-de</option>
</optgroup>

<optgroup label="Session C">
  <option value="product_de-en_beta_test_C" onclick="document.getElementById('key').value=this.value;">de-en</option>
  <option value="product_en-de_beta_test_C" onclick="document.getElementById('key').value=this.value;">en-de</option>
  <option value="product_en-de_beta_test_1_C" onclick="document.getElementById('key').value=this.value;">C* en-de</option>
  <option value="product_de-en_beta_test_1_C" onclick="document.getElementById('key').value=this.value;">C* de-en</option>
</optgroup>

<optgroup label="Session D">
  <option value="product_de-en_beta_test_D" onclick="document.getElementById('key').value=this.value;">de-en</option>
  <option value="product_en-de_beta_test_D" onclick="document.getElementById('key').value=this.value;">en-de</option>
  <option value="product_de-en_beta_test_1_D" onclick="document.getElementById('key').value=this.value;">D* de-en</option>
  <option value="product_en-de_beta_test_1_D" onclick="document.getElementById('key').value=this.value;">D* en-de</option>
</optgroup>-->



</div>


<?php include("inc/footer.inc.php"); ?>

</body>
</html>

