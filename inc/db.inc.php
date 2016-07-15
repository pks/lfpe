<?php

$SESSION_DIR="/srv/postedit/sessions";
$key = $_GET["key"];
if (preg_match('/^[a-f0-9]{1,4}$/', $key)) {
  $json = file_get_contents($SESSION_DIR."/".$key."/data.json");
}
$db = json_decode($json);

?>

