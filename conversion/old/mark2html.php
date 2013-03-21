<?php

include "parseRaw.inc.php";

if (PHP_SAPI != 'cli')
  exit;

if ($argc != 3)
  die("Fel antal argument, anvand med: php2html fran.txt till.html");

$str = simpleText(file_get_contents($argv[1]));
$fh = fopen($argv[2], "w");
fwrite($fh, $str);

?>