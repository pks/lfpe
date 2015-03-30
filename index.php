<html>
<head>
<meta charset="utf-8" />
<title>Post-editing application</title>
</head>

<body onload="alertmessage()"> 
<script type="text/javascript">
var count= 1;
var count1;

// welcome message
function alertmessage()
{
alert("Welcome to Post-editing app! \n          Good luck! =) ");
}

document.write("Please correct the machine translation from German to English.")
document.writeln("<br >"); 
document.writeln("<br >"); 


function GetSourceData()
{
var xmlhttp;
if (window.XMLHttpRequest)
  {// code for IE7+, Firefox, Chrome, Opera, Safari
  xmlhttp=new XMLHttpRequest();
  }
else
  {// code for IE6, IE5
  xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
  }
xmlhttp.onreadystatechange=function()
  {
  if (xmlhttp.readyState==4 && xmlhttp.status==200)
    {
	document.getElementById("src").innerHTML=xmlhttp.responseText;
    }
  }
xmlhttp.open("POST","server_js1.php",true);
xmlhttp.setRequestHeader("Content-type","application/x-www-form-urlencoded");
xmlhttp.send("number="+count);
}

function GetTargetData()
{
var xmlhttp;
if (window.XMLHttpRequest)
  {// code for IE7+, Firefox, Chrome, Opera, Safari
  xmlhttp=new XMLHttpRequest();
  }
else
  {// code for IE6, IE5
  xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
  }
xmlhttp.onreadystatechange=function()
  {
  if (xmlhttp.readyState==4 && xmlhttp.status==200)
    {
 	document.getElementById('trgt').value= xmlhttp.responseText;
    }
  }
xmlhttp.open("POST","server_js1.php",true);
xmlhttp.setRequestHeader("Content-type","application/x-www-form-urlencoded");
xmlhttp.send("number_trgt="+count);
}


function SubmitData()
{
var xmlhttp;
if (window.XMLHttpRequest)
  {// code for IE7+, Firefox, Chrome, Opera, Safari
  xmlhttp=new XMLHttpRequest();
  }
else
  {// code for IE6, IE5
  xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
  }
xmlhttp.onreadystatechange=function()
  {
  if (xmlhttp.readyState==4 && xmlhttp.status==200)
    {
 	alert("Thank you for your submission: " +xmlhttp.responseText);
    }
  }
xmlhttp.open("POST","server_js1.php",true);
xmlhttp.setRequestHeader("Content-type","application/x-www-form-urlencoded");
xmlhttp.send("postedit="+document.getElementById('trgt').value);

}


function SubmitAndGetData()
{
	SubmitData();
	GetSourceData();
	GetTargetData();
	count++;
}

function GetTargetDataAgain()
{
var xmlhttp;
if (window.XMLHttpRequest)
  {// code for IE7+, Firefox, Chrome, Opera, Safari
  xmlhttp=new XMLHttpRequest();
  }
else
  {// code for IE6, IE5
  xmlhttp=new ActiveXObject("Microsoft.XMLHTTP");
  }
xmlhttp.onreadystatechange=function()
  {
  if (xmlhttp.readyState==4 && xmlhttp.status==200)
    {
 	document.getElementById('trgt').value= xmlhttp.responseText;
    }
  }
xmlhttp.open("POST","server_js1.php",true);
xmlhttp.setRequestHeader("Content-type","application/x-www-form-urlencoded");
if (count==1)
{
	count1 = -5;
} 
else 
{
	count1 = count -1;
}
xmlhttp.send("number_trgt="+count1);
}

</script>




<h3>There is a source sentence.</h3>
<form action="textarea.htm">
<textarea id="src" style="font-size: 20px" name="source" cols="130" rows="2" readonly><?php $mySourceFile = fopen("source.txt", "r") or die("Unable to open file!"); 
echo fgets($mySourceFile);
fclose($mySourceFile); 
?></textarea>
</form><br><br/>

<h3>Please post-edit the SMT output.</h3>
<form action="textarea.htm"> 
<textarea id="trgt" style="font-size: 20px" name="target" cols="130" rows="2"><?php 
$myTargetFile = fopen("target.txt", "r") or die("Unable to open file!");
$SMToutput = fgets($myTargetFile);
echo $SMToutput; 
fclose($myTargetFile);
?></textarea><br><br/>
</form>


<button type="button" onclick="GetTargetDataAgain()">Revert to SMT output</button>

<button type="button" onclick="SubmitAndGetData()">Submit postedit</button>

</body>
</html>
