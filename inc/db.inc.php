<?php

$SESSION_DIR="/srv/postedit/sessions";
$json = file_get_contents($SESSION_DIR."/".$_GET["key"]."/data.json");
$db = json_decode($json);

?>

