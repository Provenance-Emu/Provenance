

function print(str)
{
    WScript.Echo(str);
}

function error()
{
	WScript.Quit();
}

prefix = "";
postfix=";";
function out(str)
{
    WScript.Echo(prefix + str + postfix);
}




function ParseOperand(str, size)
{
	var operand = new Object;
	
	if (str!=null)
	{
		operand.str = str;

		if (str.charAt(0)=='$')
		{
			operand.reg = str;
			operand.creg = "t" + str.charAt(1);
		} else
		if (str.charAt(0)=='0' && str.charAt(1)=='x')
		{
			operand.imm = parseInt(str,16);
			operand.creg = str;
		} else
		if ((str.charAt(0)>='0' && str.charAt(0)<='9') || str.charAt(0)=='-')
		{
			operand.imm = parseInt(str);
			operand.creg = str;
		} else
		{
			operand.reg = str;
			operand.creg = "r_" + str;
			if (size) operand.creg+=size;
		}
	}
	return operand;
}


DoneOps = new Array(0x800);

function startop(op, opmod, cycles)
{
	var str;
	DoneOps[op | (opmod<<8)] = true;
	
	str=((opmod<<8)|op).toString(16);
	while(str.length < 3) str="0" + str;

	out("SNSPC_OP(0x" + str + ","+ cycles + ")");
//	out("case 0x" + str + ":");
}


function assembleop(opnode)
{
    var opcode = opnode.getAttribute("code");
    var size = opnode.getAttribute("size");
    
    var op = parseInt(opcode);

//	print(op.toString(16));
//	return;

	var cycles = opnode.getAttribute("cycles");

	// get op flags
	var flagm = opnode.getAttribute("m"); 
	var flagx = opnode.getAttribute("x");
	var flage = opnode.getAttribute("e");
	if (flagm!=null) flagm=parseInt(flagm);
	if (flagx!=null) flagx=parseInt(flagx);
	if (flage!=null) flage=parseInt(flage);
	
	print("\t// " + opnode.getAttribute("name"));
	//print(flagm);
//	print("//"  +flage);

	startop(op, 0x0, cycles);
	
	prefix = "\t";
	postfix=";";

	var memreads = 0;
	// add 1 for opcode fetch
	memreads+=1;
	
	for (var j=0; j < opnode.childNodes.length; j++)
	{
		var uopnode = opnode.childNodes.item(j);
		var inst=uopnode.getAttribute("inst");
		var size = uopnode.getAttribute("size");
		if (size!=null) size=parseInt(size);
		var dest=ParseOperand(uopnode.getAttribute("dest"),size);
		var src=ParseOperand(uopnode.getAttribute("src"),size);
		
		//print("// " + inst);
		
			
		switch(inst)
		{
		case "SF":
			switch(dest.reg)
			{
			case "I":
				if (src.imm) out("SNSPC_SETFLAG_I()"); 
					else	 out("SNSPC_CLRFLAG_I()"); 
				break;
			case "D":
				if (src.imm) out("SNSPC_SETFLAG_D()"); 
					else	 out("SNSPC_CLRFLAG_D()"); 
				break;
			case "P":
				if (src.imm) out("SNSPC_SETFLAG_P()"); 
					else	 out("SNSPC_CLRFLAG_P()"); 
				break;
			case "V":
				if (src.imm!=null)
				out("SNSPC_SETFLAGI_V(" + src.creg + ")");
				else
				out("SNSPC_SETFLAG_V(" + src.creg + ")");
				break;

			case "H":
				out("SNSPC_SETFLAG_H(" + src.creg + ")"); 
				break;

			case "E":
				out("SNSPC_SETFLAG_E(" + src.creg + ")"); 
				break;

			case "C":
				if (src.imm!=null)
				out("SNSPC_SETFLAGI_C(" + src.creg + ")");
				else
				out("SNSPC_SETFLAG_C(" + src.creg + ")");
				break;				
				
			case "Z":
				if (src.imm==null && size)
					out("SNSPC_SETFLAG_Z"+size+"("+src.creg+")");
					//out("fZ=" + src.creg + "<<" + (16 - size));
				else
					error();
				break;				

			case "N":
				if (src.imm==null && size)
					out("SNSPC_SETFLAG_N"+size+"("+src.creg+")");
//					out("fN=" + src.creg + "<<" + (16 - size));
				else 
					error();					
				break;				

			default:
				error();
			}
			break;

		case "LM":
			switch (size)
			{
				case 8: 
					out("SNSPC_READ8("+src.creg+","+dest.creg + ")"); 
					memreads+=1;
					break;
				case 16: 
					out("SNSPC_READ16("+src.creg+","+dest.creg + ")"); 
					memreads+=2;
					break;
				case 24: 
					out("SNSPC_READ24("+src.creg+","+dest.creg + ")"); 
					memreads+=3;
					break;
			}
			break;

			
		case "LI":
			switch (size)
			{
				case 8: 
					out("SNSPC_FETCH8("+dest.creg+")"); 
					memreads+=1;
					break;
				case 16: 
					out("SNSPC_FETCH16("+dest.creg+")"); 
					memreads+=2;
					break;
				case 24:
					out("SNSPC_FETCH24("+dest.creg+")"); 
					memreads+=3;
					break;			}
			break;
		case "MACRO":
//			out(dest.str + "()");
			break;

		case "OR":
		case "AND":
		case "ADD":
		case "XOR":
		case "SUB":
		case "SHR":
		case "SHL":
		case "MOVE":
			if (src.imm!=null)
			out("SNSPC_" + inst + "I(" + dest.creg  + "," + src.creg + ")"); 
			else
			out("SNSPC_" + inst + "(" + dest.creg  + "," + src.creg + ")"); 
			break;			
			
		case "PUSH":
			switch (size)
			{
				case 8: 
					memreads+=1;
					break;
				case 16: 
					memreads+=2;
					break;
				case 24:
					memreads+=3;
					break;			
			}
			out("SNSPC_PUSH" + size+ "(" + dest.creg +")"); 
			break;			

		case "POP":
			switch (size)
			{
				case 8: 
					memreads+=1;
					break;
				case 16: 
					memreads+=2;
					break;
				case 24:
					memreads+=3;
					break;			
			}
			out("SNSPC_POP" + size+ "(" + dest.creg +")"); 
            
			break;			
		case "ADC":
			out("SNSPC_ADC"+size+"(" + dest.creg  + "," + src.creg + ")"); 
			break;			
		case "SBC":
			out("SNSPC_SBC"+size+"(" + dest.creg  + "," + src.creg + ")"); 
			break;			

		case "MUL":
			out("SNSPC_MUL"+(size ? size : "")+"(" + dest.creg  + "," + src.creg + ")"); 
			break;			


		case "LR":
			//if (src.reg=="P")	out("SNCPU_COMPOSEFLAGS()");
			if (src.imm!=null)
			out("SNSPC_GETI(" + dest.creg + "," +src.imm +  ")");
			else
			out("SNSPC_GET_"+src.reg + (size ? size : "") + "(" + dest.creg + ")");
			break;


		case "NOT":
			out("SNSPC_" + inst + size + "(" + dest.creg + ")"); 
			break;			


		case "LF":
			out("SNSPC_GETFLAG_" + src.reg + "(" +dest.creg  + ")"); 
			break;


		case "SR":
				out("SNSPC_SET_"+dest.reg + (size ? size : "") + "(" + src.creg + ")");
			break;			

		case "SM":
			switch (size)
			{
				case 8:
					out("SNSPC_WRITE8(" + dest.creg  + "," + src.creg + ")"); 
					memreads+=1;
					break;
				case 16:
					out("SNSPC_WRITE16(" + dest.creg  + "," + src.creg + ")"); 
					memreads+=2;
					break;
			}
			break;
			
		default:
			out(inst + "(" + (dest.creg ? dest.creg : "") + ")");
		}
		
	}

//	cycles -= memreads;

	prefix = "";
	postfix="";

	out("SNSPC_ENDOP(" + cycles + ")");

	out("");
	
	
	/*


	print(opnode.getAttribute("m"));
	print(opcode);
	
	for (var j=0; j < opnode.childNodes.length; j++)
	{
		var uopnode = opnode.childNodes.item(j);
		
		print(uopnode.getAttribute("inst"));
		print(uopnode.getAttribute("dest"));
		print(uopnode.getAttribute("src"));
	}
	*/
}


var filename = WScript.Arguments(0);

var xmldoc;

xmldoc = new ActiveXObject("MSXML2.DOMDocument.3.0");
if (xmldoc.load(filename))
{
    var root;
    var ops;
//    WScript.Echo("Loaded " + filename);
    
    root = xmldoc.documentElement;
    
    cpu = root.selectSingleNode("//cpu");
    ops = cpu.selectSingleNode("//ops");
    if (!ops) WScript.Quit();
    
    for (var i=0; i < ops.childNodes.length; i++)
    {
        var opnode;
        opnode = ops.childNodes.item(i);
        if (opnode.nodeName == "op")
        {
			assembleop(opnode);
        }
        //break;
    }

	nDone =0;
	for (i=0; i < 256; i++)
	{
		if (DoneOps[i]==true) nDone++;
	}
	
	print("// " + nDone + " ops completed");

/*
	for (i=0; i < DoneOps.length; i++)
	{
		if (DoneOps[i]!=true) startop(i, "");
		out("SNSPC_SUBCYCLES(1);");
		out("break;");
	}
*/

	//xmldoc.save(outfilename);
    //WScript.Echo("Saved " + outfilename);
} else
{
	print("Error loading " + filename);
}









