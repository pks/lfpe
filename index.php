<html>
<head>
  <meta charset="utf-8" />
  <title>Post-editing application</title>
  <script src="lfpe.js"></script>
  <link rel="stylesheet" type="text/css" href="lfpe.css" />
</head>

<body onload="">

<?php include("header.php"); ?>

<form method="get" action="interface.php">
  Please enter your session key: <input type="text" id="key" name="key" />
<input type="submit" value="Submit" />
</form>

<div class="small" style="margin-top:10em">
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
  <option value="tiny_test" onclick="document.getElementById('key').value=this.value;">toy example</option>
</select>
</p>
</div>

<?php include("footer.php"); ?>

</body>
</html>

