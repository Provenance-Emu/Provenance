

function print(str)
{
    WScript.Echo(str);
}

function parseline(line)
{
    var tokens;
    
    // strip comment
    line = line.replace(/;.*$/, "");
    
    if (line.length > 0)
    {
        // split by seperator
        tokens = line.split(/[ \t,]+/);
    
        if (tokens.length > 0)
        {
            return tokens;
        }
    }
    return null;
}

function asmuop(tokens)
{
    var uop;
    
    uop = new Object;
    
    var t= tokens[0].split(".");
    
    uop.inst = t[0];
    if (t.length >=1)
    {
        uop.size = t[1];
    } 
    
    if (tokens.length>=2)
    {
        uop.dest = tokens[1];
    }

    if (tokens.length>=3)
    {
        uop.src  = tokens[2];
    }
    
    return uop;
}

function assemble(opcode, text, defaultsize)
{
    var lines;
    var uops = new Array;
    
    lines = text.split(/\n/);
    for (var i=0; i < lines.length; i++)
    {
        var tokens;
        tokens = parseline(lines[i]);
        if (tokens)
        {
            var str;
         
            uop = asmuop(tokens);
            if (uop)
            {
				if (uop.size=="x") uop.size=defaultsize;
				uops.push(uop);
            }
        }
    }
    
    return uops;
}



var filename = WScript.Arguments(0);
var outfilename = WScript.Arguments(1);

var xmldoc;

xmldoc = new ActiveXObject("MSXML2.DOMDocument.3.0");
if (xmldoc.load(filename))
{
    var root;
    var ops;
    WScript.Echo("Loaded " + filename);
    
    root = xmldoc.documentElement;
    
    cpu = root.selectSingleNode("//cpu");
    ops = cpu.selectSingleNode("//ops");
    if (!ops) WScript.Quit();
    
    for (var i=0; i < ops.childNodes.length; i++)
    {
        var child;
        child = ops.childNodes.item(i);
        if (child.nodeName == "op")
        {
            var opcode = child.getAttribute("code");
            var size = child.getAttribute("size");
            if (opcode)
            {
				var uops;
				uops = assemble(opcode, child.text, size);
				child.text="";
                for (var j in uops)
                {
					var node;
					node = xmldoc.createElement("uop");
					node.setAttribute("inst", uops[j].inst);
					if (uops[j].dest)
						node.setAttribute("dest", uops[j].dest);
					if (uops[j].src)
						node.setAttribute("src", uops[j].src);
					if (uops[j].size)
						node.setAttribute("size", uops[j].size);
					
					child.appendChild(node);
                }
                
            }
        }
        //break;
    }

	xmldoc.save(outfilename);
    WScript.Echo("Saved " + outfilename);
} else
{
	print("Error loading " + filename);
}









