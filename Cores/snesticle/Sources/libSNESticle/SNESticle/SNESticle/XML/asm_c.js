

function print(str)
{
    WScript.Echo(str);
}

function error()
{
	WScript.Quit();
}

prefix = "";
postfix="";
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
			operand.creg = "R_t" + str.charAt(1);
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
			operand.creg = "R_" + str;
//			if (size) operand.creg+=size;
		}
	}
	return operand;
}


DoneOps = new Array(0x800);

function startop(op, opmod)
{
	var str;
	DoneOps[op | (opmod<<8)] = true;
	
	str=((opmod<<8)|op).toString(16);
	while(str.length < 3) str="0" + str;

	out("SNCPU_OP(0x" + str + ")");
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

	switch (flage)
	{
		case 1:
			startop(op, 0x4);
			break;
		case 0:
			startop(op, 0x0);
			startop(op, 0x1);
			startop(op, 0x2);
			startop(op, 0x3);
			break;
		default:			
		switch (flagx)
		{
			case 0:
				switch (flagm)
				{
					case 0:
						startop(op, 0x0);
						break;
					case 1:
						startop(op, 0x2);
						break;
					default:
						startop(op, 0x0);
						startop(op, 0x2);
						break;
				}
				break;
			case 1:
				switch (flagm)
				{
					case 0:
						startop(op, 0x1);
						break;
					case 1:
						startop(op, 0x3);
						startop(op, 0x4);
						break;
					default:
						startop(op, 0x1);
						startop(op, 0x3);
						startop(op, 0x4);
						break;
				}
				break;
			default:
				switch (flagm)
				{
					case 0:
						startop(op, 0x0);
						startop(op, 0x1);
						break;
					case 1:
						startop(op, 0x2);
						startop(op, 0x3);
						startop(op, 0x4);
						break;
					default:
						startop(op, 0x0);
						startop(op, 0x1);
						startop(op, 0x2);
						startop(op, 0x3);
						startop(op, 0x4);
						break;
				}
				break;
	
		}
	}
	
	prefix = "\t";
	postfix="";

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
				if (src.imm) out("SNCPU_SETFLAG_I()"); 
					else	 out("SNCPU_CLRFLAG_I()"); 
				break;
			case "D":
				if (src.imm) out("SNCPU_SETFLAG_D()"); 
					else	 out("SNCPU_CLRFLAG_D()"); 
				break;
			case "V":
				//if (src.creg)
				//out("SNCPU_SETFLAG_V(" + src.creg + ")"); 
				//if (src.imm) out("SNCPU_SETFLAG_V()"); 
				//	else	 out("SNCPU_CLRFLAG_V()"); 
				if (src.imm!=null)
				out("SNCPU_SETFLAGI_V(" + src.creg + ")");
				else
				out("SNCPU_SETFLAG_V(" + src.creg + ")");
				break;
			case "E":
				out("SNCPU_SETFLAG_E(" + src.creg + ")"); 
				break;

			case "C":
				if (src.imm!=null)
				out("SNCPU_SETFLAGI_C(" + src.creg + ")");
				else
				out("SNCPU_SETFLAG_C(" + src.creg + ")");
				break;				
				
			case "Z":
				if (src.imm==null && size)
					out("SNCPU_SETFLAG_Z"+size+"("+src.creg+")");
					//out("fZ=" + src.creg + "<<" + (16 - size));
				else
					error();
				break;				

			case "N":
				if (src.imm==null && size)
					out("SNCPU_SETFLAG_N"+size+"("+src.creg+")");
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
					out("SNCPU_READ8("+src.creg+","+dest.creg + ")"); 
					memreads+=1;
					break;
				case 16: 
					out("SNCPU_READ16("+src.creg+","+dest.creg + ")"); 
					memreads+=2;
					break;
				case 24: 
					out("SNCPU_READ24("+src.creg+","+dest.creg + ")"); 
					memreads+=3;
					break;
			}
			break;
			
		case "LI":
			switch (size)
			{
				case 8: 
					out("SNCPU_FETCH8("+dest.creg+")"); 
					memreads+=1;
					break;
				case 16: 
					out("SNCPU_FETCH16("+dest.creg+")"); 
					memreads+=2;
					break;
				case 24:
					out("SNCPU_FETCH24("+dest.creg+")"); 
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
			if (src.imm!=null)
			out("SNCPU_" + inst + "I(" + dest.creg  + "," + src.creg + ")"); 
			else
			out("SNCPU_" + inst + "(" + dest.creg  + "," + src.creg + ")"); 
			break;			

		case "NOT":
			out("SNCPU_" + inst + size + "(" + dest.creg + ")"); 
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
			out("SNCPU_PUSH" + size+ "(" + dest.creg +")"); 
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
			//out(dest.creg + "= SNCPU_POP"+size+"()"); 
			out("SNCPU_POP" + size+ "(" + dest.creg +")"); 
			break;			
		case "ADC":
			out("SNCPU_ADC"+size+"(" + dest.creg  + "," + src.creg + ")"); 
			break;			

		case "SBC":
			out("SNCPU_SBC"+size+"(" + dest.creg  + "," + src.creg + ")"); 
			break;			

		case "LR":
			//if (src.reg=="P")	out("SNCPU_COMPOSEFLAGS()");
			if (src.imm!=null)
			out("SNCPU_GETI(" + dest.creg + "," +src.imm +  ")");
			else
			out("SNCPU_GET_"+src.reg + (size ? size : "") + "(" + dest.creg + ")");
			break;
			
		case "LF":
			out("SNCPU_GETFLAG_" + src.reg + "(" +dest.creg  + ")"); 
			break;
			
		case "SR":
			switch (dest.reg)
			{

			case "S":
			case "X":
			case "Y":
			case "A":
			case "DP":
			case "DB":
			case "P":
			case "PC":
				out("SNCPU_SET_"+dest.reg + (size ? size : "") + "(" + src.creg + ")");
				//if (dest.reg=="P")	out("SNCPU_DECOMPOSEFLAGS()");
				break;				
				
			default:
				error();
			}
			break;
        case "CYCLE":
            memreads += dest.imm;
			out("SNCPU_SUBCYCLES(" + dest.imm + ")"); 
            break;			
		case "SM":
			switch (size)
			{
				case 8:
					out("SNCPU_WRITE8(" + dest.creg  + "," + src.creg + ")"); 
					memreads+=1;
					break;
				case 16:
					out("SNCPU_WRITE16(" + dest.creg  + "," + src.creg + ")"); 
					memreads+=2;
					break;
			}
			break;
			
		default:
			out(inst + "(" + (dest.creg ? dest.creg : "") + ")");
		}
		
	}

	cycles -= memreads;


    if (cycles < 0)
    {
        out("NEGATIVE CYCLES");
        error();
    }
	
	out("SNCPU_ENDOP(" + cycles + ")");
	prefix = "";
	postfix="";
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

/*
	nDone =0;
	for (i=0; i < 256; i++)
	{
		if (DoneOps[i]==true) nDone++;
	}
	
	print("// " + nDone + " ops completed");
*/

	out("SNCPU_OPTABLE_BEGIN()");
	for (i=0; i <= 0x4FF; i++)
	{
	str=i.toString(16);
	while(str.length < 3) str="0" + str;
		out("SNCPU_OPTABLE_OP(0x"+str+")");
	}
	out("SNCPU_OPTABLE_END()");
	

/*
	for (i=0; i < DoneOps.length; i++)
	{
		if (DoneOps[i]!=true) startop(i, "");
		out("SNCPU_SUBCYCLES(1);");
		out("break;");
	}
*/

	//xmldoc.save(outfilename);
    //WScript.Echo("Saved " + outfilename);
} else
{
	print("Error loading " + filename);
}









