

#include <string.h>
#include "types.h"
#include "console.h"
#include "sndsp1.h"


#include "sn9x/dsp1emu.c"




//
//
//



Uint32 blah;

static Uint32 _SNDSP1Execute(Uint8 uCmd, const Uint16 *pInputs, Uint32 nInputs, Int16 *pOutputs, Uint32 nOutputs)
{
	Uint32 uOutCount = 0;
	Uint8 *pOutputs8 = (Uint8 *)pOutputs;

	switch (uCmd)
	{
	case 0x1f:
		//uOutCount=2048;
		break;
	case 0x00:	// Multiple
		Op00Multiplicand = (Int16) pInputs[0];
		Op00Multiplier = (Int16) pInputs[1];

		DSPOp00 ();

		uOutCount = 2;
		pOutputs8 [0] = Op00Result&0xFF;
		pOutputs8 [1] = (Op00Result>>8)&0xFF;
		break;

	case 0x20:	// Multiple
		Op20Multiplicand = (Int16) pInputs[0];
		Op20Multiplier = (Int16) pInputs[1];

		DSPOp20 ();

		uOutCount = 2;
		pOutputs8 [0] = Op20Result&0xFF;
		pOutputs8 [1] = (Op20Result>>8)&0xFF;
		break;

	case 0x30:
	case 0x10:	// Inverse
		Op10Coefficient = (Int16) pInputs[0];
		Op10Exponent = (Int16) pInputs[1];

		DSPOp10 ();

		uOutCount = 4;
		pOutputs8 [0] = (Uint8) (((Int16) Op10CoefficientR)&0xFF);
		pOutputs8 [1] = (Uint8) ((((Int16) Op10CoefficientR)>>8)&0xFF);
		pOutputs8 [2] = (Uint8) (((Int16) Op10ExponentR)&0xff);
		pOutputs8 [3] = (Uint8) ((((Int16) Op10ExponentR)>>8)&0xff);
		break;

	case 0x24:
	case 0x04:	// Sin and Cos of angle
		Op04Angle = (Int16) pInputs[0];
		Op04Radius = (Uint16) pInputs[1];

		DSPOp04 ();

		uOutCount = 4;
		pOutputs8 [0] = (Uint8) (Op04Sin&0xFF);
		pOutputs8 [1] = (Uint8) ((Op04Sin>>8)&0xFF);
		pOutputs8 [2] = (Uint8) (Op04Cos&0xFF);
		pOutputs8 [3] = (Uint8) ((Op04Cos>>8)&0xFF);
		break;

	case 0x08:	// Radius
		Op08X = (Int16) pInputs[0];
		Op08Y = (Int16) pInputs[1];
		Op08Z = (Int16) pInputs[2];

		DSPOp08 ();

		uOutCount = 4;
		pOutputs8 [0] = (Uint8) (((Int16) Op08Ll)&0xFF); 
		pOutputs8 [1] = (Uint8) ((((Int16) Op08Ll)>>8)&0xFF); 
		pOutputs8 [2] = (Uint8) (((Int16) Op08Lh)&0xFF);
		pOutputs8 [3] = (Uint8) ((((Int16) Op08Lh)>>8)&0xFF);
		break;

	case 0x18:	// Range

		Op18X = (Int16) pInputs[0];
		Op18Y = (Int16) pInputs[1];
		Op18Z = (Int16) pInputs[2];
		Op18R = (Int16) pInputs[3];

		DSPOp18 ();

		uOutCount = 2;
		pOutputs8 [0] = (Uint8) (Op18D&0xFF);
		pOutputs8 [1] = (Uint8) ((Op18D>>8)&0xFF);
		break;

	case 0x38:	// Range

		Op38X = (Int16) pInputs[0];
		Op38Y = (Int16) pInputs[1];
		Op38Z = (Int16) pInputs[2];
		Op38R = (Int16) pInputs[3];

		DSPOp38 ();

		uOutCount = 2;
		pOutputs8 [0] = (Uint8) (Op38D&0xFF);
		pOutputs8 [1] = (Uint8) ((Op38D>>8)&0xFF);
		break;

	case 0x28:	// Distance (vector length)
		Op28X = (Int16) pInputs[0];
		Op28Y = (Int16) pInputs[1];
		Op28Z = (Int16) pInputs[2];

		DSPOp28 ();

		uOutCount = 2;
		pOutputs8 [0] = (Uint8) (Op28R&0xFF);
		pOutputs8 [1] = (Uint8) ((Op28R>>8)&0xFF);
		break;

	case 0x2c:
	case 0x0c:	// Rotate (2D rotate)
		Op0CA = (Int16) pInputs[0];
		Op0CX1 = (Int16) pInputs[1];
		Op0CY1 = (Int16) pInputs[2];

		DSPOp0C ();

		uOutCount = 4;
		pOutputs8 [0] = (Uint8) (Op0CX2&0xFF);
		pOutputs8 [1] = (Uint8) ((Op0CX2>>8)&0xFF);
		pOutputs8 [2] = (Uint8) (Op0CY2&0xFF);
		pOutputs8 [3] = (Uint8) ((Op0CY2>>8)&0xFF);
		break;

	case 0x3c:
	case 0x1c:	// Polar (3D rotate)
		Op1CZ = pInputs[0];
		//MK: reversed X and Y on neviksti and John's advice.
		Op1CY = pInputs[1];
		Op1CX = pInputs[2];
		Op1CXBR = pInputs[3];
		Op1CYBR = pInputs[4];
		Op1CZBR = pInputs[5];

		DSPOp1C ();

		uOutCount = 6;
		pOutputs8 [0] = (Uint8) (Op1CXAR&0xFF);
		pOutputs8 [1] = (Uint8) ((Op1CXAR>>8)&0xFF);
		pOutputs8 [2] = (Uint8) (Op1CYAR&0xFF);
		pOutputs8 [3] = (Uint8) ((Op1CYAR>>8)&0xFF);
		pOutputs8 [4] = (Uint8) (Op1CZAR&0xFF);
		pOutputs8 [5] = (Uint8) ((Op1CZAR>>8)&0xFF);
		break;

	case 0x32:
	case 0x22:
	case 0x12:
	case 0x02:	// Parameter (Projection)
		Op02FX = (short)pInputs[0];
		Op02FY = (short)pInputs[1];
		Op02FZ = (short)pInputs[2];
		Op02LFE = (short)pInputs[3];
		Op02LES = (short)pInputs[4];
		Op02AAS = (unsigned short)pInputs[5];
		Op02AZS = (unsigned short)pInputs[6];

		DSPOp02 ();

		uOutCount = 8;
		pOutputs8 [0] = (Uint8) (Op02VOF&0xFF);
		pOutputs8 [1] = (Uint8) ((Op02VOF>>8)&0xFF);
		pOutputs8 [2] = (Uint8) (Op02VVA&0xFF);
		pOutputs8 [3] = (Uint8) ((Op02VVA>>8)&0xFF);
		pOutputs8 [4] = (Uint8) (Op02CX&0xFF);
		pOutputs8 [5] = (Uint8) ((Op02CX>>8)&0xFF);
		pOutputs8 [6] = (Uint8) (Op02CY&0xFF);
		pOutputs8 [7] = (Uint8) ((Op02CY>>8)&0xFF);
		break;

	case 0x3a:  //1a Mirror
	case 0x2a:  //1a Mirror
	case 0x1a:	// Raster mode 7 matrix data
	case 0x0a:
		Op0AVS = (short)pInputs[0];

		DSPOp0A ();

		uOutCount = 8;
		pOutputs8 [0] = (Uint8) (Op0AA&0xFF);
		pOutputs8 [2] = (Uint8) (Op0AB&0xFF);
		pOutputs8 [4] = (Uint8) (Op0AC&0xFF);
		pOutputs8 [6] = (Uint8) (Op0AD&0xFF);
		pOutputs8 [1] = (Uint8) ((Op0AA>>8)&0xFF);
		pOutputs8 [3] = (Uint8) ((Op0AB>>8)&0xFF);
		pOutputs8 [5] = (Uint8) ((Op0AC>>8)&0xFF);
		pOutputs8 [7] = (Uint8) ((Op0AD>>8)&0xFF);
//		DSP1.in_index=0; hmm
		break;

	case 0x16:
	case 0x26:
	case 0x36:
	case 0x06:	// Project object
		Op06X = (Int16) pInputs[0];
		Op06Y = (Int16) pInputs[1];
		Op06Z = (Int16) pInputs[2];

		DSPOp06 ();

		uOutCount = 6;
		pOutputs8 [0] = (Uint8) (Op06H&0xff);
		pOutputs8 [1] = (Uint8) ((Op06H>>8)&0xFF);
		pOutputs8 [2] = (Uint8) (Op06V&0xFF);
		pOutputs8 [3] = (Uint8) ((Op06V>>8)&0xFF);
		pOutputs8 [4] = (Uint8) (Op06S&0xFF);
		pOutputs8 [5] = (Uint8) ((Op06S>>8)&0xFF);
		break;

	case 0x1e:
	case 0x2e:
	case 0x3e:
	case 0x0e:	// Target
		Op0EH = (Int16) pInputs[0];
		Op0EV = (Int16) pInputs[1];

		DSPOp0E ();

		uOutCount = 4;
		pOutputs8 [0] = (Uint8) (Op0EX&0xFF);
		pOutputs8 [1] = (Uint8) ((Op0EX>>8)&0xFF);
		pOutputs8 [2] = (Uint8) (Op0EY&0xFF);
		pOutputs8 [3] = (Uint8) ((Op0EY>>8)&0xFF);
		break;

		// Extra commands used by Pilot Wings
	case 0x05:
	case 0x35:
	case 0x31:
	case 0x01: // Set attitude matrix A
		Op01m = (Int16) pInputs[0];
		Op01Zr = (Int16) pInputs[1];
		Op01Yr = (Int16) pInputs[2];
		Op01Xr = (Int16) pInputs[3];

		DSPOp01 ();
		break;

	case 0x15:	
	case 0x11:	// Set attitude matrix B
		Op11m = (Int16) pInputs[0];
		Op11Zr = (Int16) pInputs[1];
		Op11Yr = (Int16) pInputs[2];
		Op11Xr = (Int16) pInputs[3];

		DSPOp11 ();
		break;

	case 0x25:
	case 0x21:	// Set attitude matrix C
		Op21m = (Int16) pInputs[0];
		Op21Zr = (Int16) pInputs[1];
		Op21Yr = (Int16) pInputs[2];
		Op21Xr = (Int16) pInputs[3];

		DSPOp21 ();
		break;

	case 0x09:
	case 0x39:
	case 0x3d:
	case 0x0d:	// Objective matrix A
		Op0DX = (Int16) pInputs[0];
		Op0DY = (Int16) pInputs[1];
		Op0DZ = (Int16) pInputs[2];

		DSPOp0D ();

		uOutCount = 6;
		pOutputs8 [0] = (Uint8) (Op0DF&0xFF);
		pOutputs8 [1] = (Uint8) ((Op0DF>>8)&0xFF);
		pOutputs8 [2] = (Uint8) (Op0DL&0xFF);
		pOutputs8 [3] = (Uint8) ((Op0DL>>8)&0xFF);
		pOutputs8 [4] = (Uint8) (Op0DU&0xFF);
		pOutputs8 [5] = (Uint8) ((Op0DU>>8)&0xFF);
		break;

	case 0x19:
	case 0x1d:	// Objective matrix B
		Op1DX = (Int16) pInputs[0];
		Op1DY = (Int16) pInputs[1];
		Op1DZ = (Int16) pInputs[2];

		DSPOp1D ();

		uOutCount = 6;
		pOutputs8 [0] = (Uint8) (Op1DF&0xFF);
		pOutputs8 [1] = (Uint8) ((Op1DF>>8)&0xFF);
		pOutputs8 [2] = (Uint8) (Op1DL&0xFF);
		pOutputs8 [3] = (Uint8) ((Op1DL>>8)&0xFF);
		pOutputs8 [4] = (Uint8) (Op1DU&0xFF);
		pOutputs8 [5] = (Uint8) ((Op1DU>>8)&0xFF);
		break;

	case 0x29:
	case 0x2d:	// Objective matrix C
		Op2DX = (Int16) pInputs[0];
		Op2DY = (Int16) pInputs[1];
		Op2DZ = (Int16) pInputs[2];

		DSPOp2D ();

		uOutCount = 6;
		pOutputs8 [0] = (Uint8) (Op2DF&0xFF);
		pOutputs8 [1] = (Uint8) ((Op2DF>>8)&0xFF);
		pOutputs8 [2] = (Uint8) (Op2DL&0xFF);
		pOutputs8 [3] = (Uint8) ((Op2DL>>8)&0xFF);
		pOutputs8 [4] = (Uint8) (Op2DU&0xFF);
		pOutputs8 [5] = (Uint8) ((Op2DU>>8)&0xFF);
		break;

	case 0x33:
	case 0x03:	// Subjective matrix A
		Op03F = (Int16) pInputs[0];
		Op03L = (Int16) pInputs[1];
		Op03U = (Int16) pInputs[2];

		DSPOp03 ();

		uOutCount = 6;
		pOutputs8 [0] = (Uint8) (Op03X&0xFF);
		pOutputs8 [1] = (Uint8) ((Op03X>>8)&0xFF);
		pOutputs8 [2] = (Uint8) (Op03Y&0xFF);
		pOutputs8 [3] = (Uint8) ((Op03Y>>8)&0xFF);
		pOutputs8 [4] = (Uint8) (Op03Z&0xFF);
		pOutputs8 [5] = (Uint8) ((Op03Z>>8)&0xFF);
		break;

	case 0x13:	// Subjective matrix B
		Op13F = (Int16) pInputs[0];
		Op13L = (Int16) pInputs[1];
		Op13U = (Int16) pInputs[2];

		DSPOp13 ();

		uOutCount = 6;
		pOutputs8 [0] = (Uint8) (Op13X&0xFF);
		pOutputs8 [1] = (Uint8) ((Op13X>>8)&0xFF);
		pOutputs8 [2] = (Uint8) (Op13Y&0xFF);
		pOutputs8 [3] = (Uint8) ((Op13Y>>8)&0xFF);
		pOutputs8 [4] = (Uint8) (Op13Z&0xFF);
		pOutputs8 [5] = (Uint8) ((Op13Z>>8)&0xFF);
		break;

	case 0x23:	// Subjective matrix C
		Op23F = (Int16) pInputs[0];
		Op23L = (Int16) pInputs[1];
		Op23U = (Int16) pInputs[2];

		DSPOp23 ();

		uOutCount = 6;
		pOutputs8 [0] = (Uint8) (Op23X&0xFF);
		pOutputs8 [1] = (Uint8) ((Op23X>>8)&0xFF);
		pOutputs8 [2] = (Uint8) (Op23Y&0xFF);
		pOutputs8 [3] = (Uint8) ((Op23Y>>8)&0xFF);
		pOutputs8 [4] = (Uint8) (Op23Z&0xFF);
		pOutputs8 [5] = (Uint8) ((Op23Z>>8)&0xFF);
		break;

	case 0x3b:
	case 0x0b:
		Op0BX = (Int16) pInputs[0];
		Op0BY = (Int16) pInputs[1];
		Op0BZ = (Int16) pInputs[2];

		DSPOp0B ();

		uOutCount = 2;
		pOutputs8 [0] = (Uint8) (Op0BS&0xFF);
		pOutputs8 [1] = (Uint8) ((Op0BS>>8)&0xFF);
		break;

	case 0x1b:
		Op1BX = (Int16) pInputs[0];
		Op1BY = (Int16) pInputs[1];
		Op1BZ = (Int16) pInputs[2];

		DSPOp1B ();

		uOutCount = 2;
		pOutputs8 [0] = (Uint8) (Op1BS&0xFF);
		pOutputs8 [1] = (Uint8) ((Op1BS>>8)&0xFF);
		break;

	case 0x2b:
		Op2BX = (Int16) pInputs[0];
		Op2BY = (Int16) pInputs[1];
		Op2BZ = (Int16) pInputs[2];

		DSPOp0B ();

		uOutCount = 2;
		pOutputs8 [0] = (Uint8) (Op2BS&0xFF);
		pOutputs8 [1] = (Uint8) ((Op2BS>>8)&0xFF);
		break;

	case 0x34:
	case 0x14:	
		Op14Zr = (Int16) pInputs[0];
		Op14Xr = (Int16) pInputs[1];
		Op14Yr = (Int16) pInputs[2];
		Op14U = (Int16) pInputs[3];
		Op14F = (Int16) pInputs[4];
		Op14L = (Int16) pInputs[5];

		DSPOp14 ();

		uOutCount = 6;
		pOutputs8 [0] = (Uint8) (Op14Zrr&0xFF);
		pOutputs8 [1] = (Uint8) ((Op14Zrr>>8)&0xFF);
		pOutputs8 [2] = (Uint8) (Op14Xrr&0xFF);
		pOutputs8 [3] = (Uint8) ((Op14Xrr>>8)&0xFF);
		pOutputs8 [4] = (Uint8) (Op14Yrr&0xFF);
		pOutputs8 [5] = (Uint8) ((Op14Yrr>>8)&0xFF);
		break;


	case 0x27:
	case 0x2F:
		Op2FUnknown = (Int16) pInputs[0];

		DSPOp2F ();

		uOutCount = 2;
		pOutputs8 [0] = (Uint8)(Op2FSize&0xFF);
		pOutputs8 [1] = (Uint8)((Op2FSize>>8)&0xFF);
		break;

	case 0x07:
	case 0x0F:
		Op0FRamsize = (Int16) pInputs[0];

		DSPOp0F ();

		uOutCount = 2;
		pOutputs8 [0] = (Uint8)(Op0FPass&0xFF);
		pOutputs8 [1] = (Uint8)((Op0FPass>>8)&0xFF);
		break;

	default:
		break;
	}
	return uOutCount >> 1;
}

static Uint8 _SNDSP1GetCmdSize(Uint8 uCmd)
{
	Uint8 uInCount = 0;
	switch (uCmd)
	{
	case 0x00: uInCount = 2;	break;
	case 0x30:
	case 0x10: uInCount = 2;	break;
	case 0x20: uInCount = 2;	break;
	case 0x24:
	case 0x04: uInCount = 2;	break;
	case 0x08: uInCount = 3;	break;
	case 0x18: uInCount = 4;	break;
	case 0x28: uInCount = 3;	break;
	case 0x38: uInCount = 4;	break;
	case 0x2c:
	case 0x0c: uInCount = 3;	break;
	case 0x3c:
	case 0x1c: uInCount = 6;	break;
	case 0x32:
	case 0x22:
	case 0x12:
	case 0x02: uInCount = 7;	break;
	case 0x0a: uInCount = 1;	break;
	case 0x3a:
	case 0x2a:
	case 0x1a:	uInCount = 1;	break;
	case 0x16:
	case 0x26:
	case 0x36:
	case 0x06: uInCount = 3;	break;
	case 0x1e:
	case 0x2e:
	case 0x3e:
	case 0x0e: uInCount = 2;	break;
	case 0x05:
	case 0x35:
	case 0x31:
	case 0x01: uInCount = 4;	break;
	case 0x15:
	case 0x11: uInCount = 4;	break;
	case 0x25:
	case 0x21: uInCount = 4;	break;
	case 0x09:
	case 0x39:
	case 0x3d:
	case 0x0d: uInCount = 3;	break;
	case 0x19:
	case 0x1d: uInCount = 3;	break;
	case 0x29:
	case 0x2d: uInCount = 3;	break;
	case 0x33:
	case 0x03: uInCount = 3;	break;
	case 0x13: uInCount = 3;	break;
	case 0x23: uInCount = 3;	break;
	case 0x3b:
	case 0x0b: uInCount = 3;	break;
	case 0x1b: uInCount = 3;	break;
	case 0x2b: uInCount = 3;	break;
	case 0x34:
	case 0x14: uInCount = 6;	break;
	case 0x07:
	case 0x0f: uInCount = 1;	break;
	case 0x27:
	case 0x2F: uInCount=1; break;
		/*
	case 0x17:
	case 0x37:
	case 0x3F:	DSP1.command=0x1f;
		*/
	case 0x1f: uInCount = 1;	break;
	default:
		uInCount = 0;
		break;
	}

	return uInCount;
}

SNDSP1::SNDSP1()
{
	Reset();
}

void SNDSP1::Reset()
{
	m_uCmd = 0x80;
	m_bIdle = TRUE;

	m_uInAddr  = 0;
	m_uInSize = 0;
	memset(m_InData, 0, sizeof(m_InData));

	m_uOutAddr = 0;
	m_uOutSize = 0;
	memset(m_OutData, 0, sizeof(m_OutData));
}

Uint8 SNDSP1::ReadData(Uint32 uAddr)
{
	//ConDebug("read_dsp1[]\n");

	Uint8 uData = 0xFF;
	if (m_uOutAddr < m_uOutSize)
	{
		if (!(m_uOutAddr & 1))
		{
			uData = (Uint8)(m_OutData[m_uOutAddr >> 1] >> 0);
		} else
		{
			uData = (Uint8)(m_OutData[m_uOutAddr >> 1] >> 8);
		}

		// increment out addr
		m_uOutAddr++;

		if (m_uOutAddr == m_uOutSize)
		{
			if (m_uCmd == 0x0A)
			{
				// re-execute
				// execute command
				m_uOutAddr = 0;
				m_uOutSize = _SNDSP1Execute(m_uCmd, m_InData, m_uInAddr >> 1, (short *)m_OutData, sizeof(m_OutData) >> 1);

				m_uInAddr = 0;
			}

			// we're idle again
			m_bIdle = TRUE;
		}

	} else
	{
		// they're trying to read beyond the end of data that was output
		// ..
		uData = 0xFF;
	}
	return uData;
}


Uint8 SNDSP1::ReadStatus(Uint32 uAddr)
{
	return 0x80;
}

void SNDSP1::WriteData(Uint32 uAddr, Uint8 uData)
{
	//ConDebug("write_dsp1[]=%02X\n", uData);

	// is command in process?
	if (m_bIdle)
	{
		m_uCmd = uData;

		// reset input address
		m_uInAddr  = 0;

		// get size of cmd in bytes
		m_uInSize = _SNDSP1GetCmdSize(uData) * 2;

		if (m_uInSize > 0)
		{
			m_bIdle = FALSE;

			// this should never happen
			assert(m_uInSize <= sizeof(m_InData));
		}
	} 
	else
	{
		if (m_uInAddr < m_uInSize)
		{
			// write to parameter array
			if (!(m_uInAddr & 1))
			{
				// set lower byte
				m_InData[m_uInAddr >> 1]  = ((Uint16)uData) << 0;
			} else
			{
				// set upper byte
				m_InData[m_uInAddr >> 1] |= ((Uint16)uData) << 8;
			}

			// advance input address
			m_uInAddr++;

			if (m_uInAddr == m_uInSize)
			{
				// execute command
				m_uOutAddr = 0;
				m_uOutSize = _SNDSP1Execute(m_uCmd, m_InData, m_uInAddr >> 1, (short *)m_OutData, sizeof(m_OutData) >> 1);
				if (m_uCmd == 0x0A)
				{
					// reset command
					m_uInAddr = 0;
				}

				// convert to bytes...
				m_uOutSize *= 2;
			}
		} else
		{
			// trying to write more data than last command needed...
			// ..
		}
	}
}








