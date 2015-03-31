<?php

if($_POST['number'])
{
$varNumber = $_POST['number'];

$mySourceFile = fopen("source.txt", "r") or die("Unable to open file!");

for ($i = 1; $i <= $varNumber; $i++) {
	fgets($mySourceFile);
}
 
if (!feof($mySourceFile)) 
	{
    		echo fgets($mySourceFile);

	}
	else 
	{
		echo "The end of the input file.";
	}
fclose($mySourceFile);
}


if($_POST['number_trgt'])
{
$varNumber = $_POST['number_trgt'];

$myTargetFile = fopen("target.txt", "r") or die("Unable to open file!");

for ($i = 1; $i <= $varNumber; $i++) {
    fgets($myTargetFile);
}
 
if (!feof($myTargetFile)) 
	{
    		echo fgets($myTargetFile);
	}
	else 
	{
		echo "The end of the input file.";
	}
fclose($myTargetFile);
}


if($_POST['postedit'])
{
$varData = $_POST['postedit'];
echo $varData;

$myFile = "testFile.txt";
file_put_contents($myFile, $varData, FILE_APPEND);
file_put_contents($myFile, PHP_EOL, FILE_APPEND); 

}

?>
