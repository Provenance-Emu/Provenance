
if (WScript.Arguments.length >=3)
{
var InFileName = WScript.Arguments(1);
var XslFileName = WScript.Arguments(0);
var OutFileName = WScript.Arguments(2);
} else
{
	WScript.Echo("Usage:  xslt xslfile infile outfile");
	WScript.Quit();
}


var xslt = new ActiveXObject("Msxml2.XSLTemplate");
var xslDoc = new ActiveXObject("Msxml2.FreeThreadedDOMDocument");
var xslProc;
xslDoc.async = false;
xslDoc.load(XslFileName);
xslt.stylesheet = xslDoc;
var xmlDoc = new ActiveXObject("Msxml2.DOMDocument");
var outDoc = new ActiveXObject("Msxml2.DOMDocument");
xmlDoc.async = false;
xmlDoc.load(InFileName);
xslProc = xslt.createProcessor();
xslProc.input = xmlDoc;
xslProc.output = outDoc;

xslProc.transform();

outDoc.save(OutFileName);

///WScript.Echo(xslProc.output);
