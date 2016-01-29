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

