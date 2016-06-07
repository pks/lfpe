<!DOCTYPE html>
<html>
<head>
  <meta http-equiv='Content-Type' content='text/html; charset=utf-8' />

  <title>Pool</title>

  <link rel='stylesheet' type='text/css' href='static/pool.css' />
  <script src="js/jquery.min.js" type="text/javascript" charset="utf-8"></script>
  <script src="js/pool.js"  type="text/javascript" charset="utf-8"></script>
</head>

<body>
  <p style='margin:2em;color:#000'><strong>Click on a table cell, enter your name, and click 'Begin' to begin your session. Reload the page if you clicked on the wrong cell.</strong></p>
  <table border=1 style="margin-left:10%">
    <tr><td>#0</td></tr>
  </table>
  <br />
  <br />
  <br />
  <br />
  <center>
  <table border=1>
    <tr>

<!--<tr><td>#1</td><td>#2</td><td>#3</td><td>#4</td><td>#5</td></tr>
    <tr><td>#6</td><td>#7</td><td>#8</td><td>#9</td><td>#10</td></tr>
    <tr><td>#11</td><td>#12</td><td>#13</td><td>#14</td><td>#15</td></tr>
    <tr><td>#16</td><td>#17</td><td>#18</td><td>#19</td><td>#20</td></tr>
    <tr><td>#21</td><td>#22</td><td>#23</td><td>#24</td><td>#25</td></tr>-->

    <?php
      $f = fopen("../sessions/sessions", "r");
      $a = array();
      $b = array();
      $max = -1;
      while (($line = fgets($f)) !== false) {
        $x = explode("\t", $line, 2);
        $j = intval($x[0]);
        $a[$x[1]] = $j;
        $b[$j] = $x[1];
        if ($j>$max) {
          $max = $j;
        }
      }
      fclose($f);  
      
      for ($i=1; $i<=$max; $i++) {
        echo "<td class='item' session='".$b[$i]."' id='item".$i."'>#".$i."<br /><span style='font-size:.5em'>".$b[$i]."</span></td>\n";
        if ($i%5 == 0) {
          echo "</tr><tr>\n";
        }
      }
    ?>

    </tr>
  </table>

  <button style="font-size:2em;margin:2em" id="button">Begin</button>

  </center>
</body>
</html>

