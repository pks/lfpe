<?php

if (!$_GET['session'] || !$_GET['name']) {
  echo "empty";
  return;
}

$f = fopen(tempnam("../tmp", "assignment-"), "wa");

fwrite($f,urldecode($_GET["name"])."\n");
fwrite($f,urldecode($_GET["session"])."\n");
fwrite($f,getdate()[0]."\n");
fclose($f);

$checkf = "../tmp/".urldecode($_GET["session"]);
if (file_exists($checkf)) {
  echo "notok";
} else {
  $g = fopen($checkf, "wa");
  fwrite($g, "x\n");
  fclose($g);
  echo "ok";
}

?>
