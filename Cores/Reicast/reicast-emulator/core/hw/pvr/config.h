#define OP_ON 1
#define OP_OFF 2

//Debugging stuff 
#define DO_VERIFY OP_OFF


//DO NOT EDIT -- overrides for default according to build options
#ifdef _DEBUG
#undef DO_VERIFY
#define DO_VERIFY OP_ON
#endif