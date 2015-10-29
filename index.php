<html>
<head>
  <meta charset="utf-8" />
  <title>Post-editing application</title>
  <script src="http://ajax.googleapis.com/ajax/libs/jquery/1.11.2/jquery.min.js" charset="utf-8"></script>
  <link rel="stylesheet" type="text/css" href="static/main.css" />
</head>

<body onload="">

<?php include("header.php"); ?>

<form method="get" action="interface.php">
  <strong>Please enter your session key:</strong> <input type="text" id="key" name="key" />
  &nbsp;&nbsp;&nbsp;&nbsp;Session type:
  <select name="ui_type">
    <option value="t">textual</option>
    <option value="g">graphical</option>
</select>
&nbsp;&nbsp;&nbsp;&nbsp;
<input type="submit" value="Submit" />
</form>

<div class="small" style="background:#eee;margin: 5em 0 5em 0;padding:.5em; max-width:20%">
<p>Beta test:
<select class="small">
  <option value="beta_test_A" onclick="document.getElementById('key').value=this.value;">A</option>
  <option value="beta_test_A_nolearn" onclick="document.getElementById('key').value=this.value;">A (no learning)</option>
  <option value="beta_test_A_nomt" onclick="document.getElementById('key').value=this.value;">A (no MT)</option>
  <option value="beta_test_A_sparse" onclick="document.getElementById('key').value=this.value;">A (sparse)</option>
  <option value="beta_test_B" onclick="document.getElementById('key').value=this.value;">B</option>
  <option value="beta_test_B_sparse" onclick="document.getElementById('key').value=this.value;">B (sparse)</option>
  <option value="beta_test_C" onclick="document.getElementById('key').value=this.value;">C</option>
  <option value="beta_test_C_sparse" onclick="document.getElementById('key').value=this.value;">C (sparse)</option>
  <option value="beta_test_D" onclick="document.getElementById('key').value=this.value;">D</option>
  <option value="beta_test_D_sparse" onclick="document.getElementById('key').value=this.value;">D (sparse)</option>
  <option value="toy_example" onclick="document.getElementById('key').value=this.value;">toy example</option>
</select>
</p>
</div>

<?php include("footer.php"); ?>

</body>
</html>

