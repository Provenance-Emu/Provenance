///this file is here to make up for C++'s limitations
static TaListFP* ta_poly_data_lut[15] = 
{
	ta_poly_data<0,SZ32>,
	ta_poly_data<1,SZ32>,
	ta_poly_data<2,SZ32>,
	ta_poly_data<3,SZ32>,
	ta_poly_data<4,SZ32>,
	ta_poly_data<5,SZ64>,
	ta_poly_data<6,SZ64>,
	ta_poly_data<7,SZ32>,
	ta_poly_data<8,SZ32>,
	ta_poly_data<9,SZ32>,
	ta_poly_data<10,SZ32>,
	ta_poly_data<11,SZ64>,
	ta_poly_data<12,SZ64>,
	ta_poly_data<13,SZ64>,
	ta_poly_data<14,SZ64>,
};
//32/64b , full
static TaPolyParamFP* ta_poly_param_lut[5]=
{
	AppendPolyParam0,
	AppendPolyParam1,
	AppendPolyParam2Full,
	AppendPolyParam3,
	AppendPolyParam4Full
};
//64b , first part
static TaPolyParamFP* ta_poly_param_a_lut[5]=
{
	(TaPolyParamFP*)0,
	(TaPolyParamFP*)0,
	AppendPolyParam2A,
	(TaPolyParamFP*)0,
	AppendPolyParam4A
};

//64b , , second part
static TaListFP* ta_poly_param_b_lut[5]=
{
	(TaListFP*)0,
	(TaListFP*)0,
	ta_poly_B_32<2>,
	(TaListFP*)0,
	ta_poly_B_32<4>
};
