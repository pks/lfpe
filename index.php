<html>
<head>
  <meta charset="utf-8" />
  <title>Post-Editing Interface</title>
  <script src="js/jquery.min.js" charset="utf-8"></script>
  <link rel="stylesheet" type="text/css" href="static/main.css" />
</head>

<body>

<?php include("inc/header.inc.php"); ?>

<form method="get" action="interface.php">
  <strong>Please enter your session key:</strong>
  <input type="text" id="key" name="key" style="width:20em" />
  &nbsp;&nbsp;&nbsp;&nbsp;Session type:
  <select name="ui_type">
    <option value="t">text</option>
    <option value="g">graphical</option>
</select>
&nbsp;&nbsp;&nbsp;&nbsp;
<input type="submit" value="Submit" />
</form>

<div class="small" style="background:#eee;margin: 5em 0 5em 0;padding:.5em; max-width:25%">
<p>Beta test:
<select class="small">

<optgroup label="________________">
  <option value="product_de-en_toy_example" onclick="document.getElementById('key').value=this.value;">toy example</option>
</optgroup>

<optgroup label="________________">
  <option value="product_de-en_toy_example" onclick="document.getElementById('key').value=this.value;">toy example</option>
  <option value="product_de-en_beta_test_A" onclick="document.getElementById('key').value=this.value;">A de-en</option>
  <option value="product_en-de_beta_test_A" onclick="document.getElementById('key').value=this.value;">A en-de</option>
  <option value="product_de-en_beta_test_1_A" onclick="document.getElementById('key').value=this.value;">A* de-en</option>
  <option value="product_en-de_beta_test_1_A" onclick="document.getElementById('key').value=this.value;">A* en-de</option>
</optgroup>

<optgroup label="________________">
  <option value="product_de-en_beta_test_B" onclick="document.getElementById('key').value=this.value;">B de-en</option>
  <option value="product_en-de_beta_test_B" onclick="document.getElementById('key').value=this.value;">B en-de</option>
  <option value="product_de-en_beta_test_1_B" onclick="document.getElementById('key').value=this.value;">B* de-en</option>
  <option value="product_en-de_beta_test_1_B" onclick="document.getElementById('key').value=this.value;">B* en-de</option>
</optgroup>

<optgroup label="________________">
  <option value="product_en-de_beta_test_C" onclick="document.getElementById('key').value=this.value;">C en-de</option>
  <option value="product_de-en_beta_test_C" onclick="document.getElementById('key').value=this.value;">C de-en</option>
  <option value="product_en-de_beta_test_1_C" onclick="document.getElementById('key').value=this.value;">C* en-de</option>
  <option value="product_de-en_beta_test_1_C" onclick="document.getElementById('key').value=this.value;">C* de-en</option>
</optgroup>

<optgroup label="________________">
  <option value="product_de-en_beta_test_D" onclick="document.getElementById('key').value=this.value;">D de-en</option>
  <option value="product_en-de_beta_test_D" onclick="document.getElementById('key').value=this.value;">D en-de</option>
  <option value="product_de-en_beta_test_1_D" onclick="document.getElementById('key').value=this.value;">D* de-en</option>
  <option value="product_en-de_beta_test_1_D" onclick="document.getElementById('key').value=this.value;">D* en-de</option>
</optgroup>
 
</select>
</p>
</div>

<?php include("inc/footer.inc.php"); ?>

</body>
</html>

