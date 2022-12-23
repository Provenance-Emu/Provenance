typedef struct
{
    int openemuButton;
    int value;
} keymap;

/*
typedef struct
{
    keymap gc_pad_keymap[22] = {
        {PVGCButtonUp, 0},
        {PVGCButtonDown, 0},
        {PVGCButtonLeft, 0},
        {PVGCButtonRight, 0},
        {PVGCAnalogUp, 0},
        {PVGCAnalogDown, 0},
        {PVGCAnalogLeft, 0},
        {PVGCAnalogRight,  0},
        {PVGCAnalogCUp,  0},
        {PVGCAnalogCDown, 0},
        {PVGCAnalogCLeft, 0},
        {PVGCAnalogCRight,  0},
        {PVGCButtonA,  0},
        {PVGCButtonB, 0},
        {PVGCButtonX, 0},
        {PVGCButtonY, 0},
        {PVGCButtonL, 0},
        {PVGCButtonR, 0},
        {PVGCButtonZ, 0},
        {PVGCButtonStart, 0},
        {PVGCDigitalL, 0},
        {PVGCDigitalR, 0},
    };
} gc_pad;
*/

void setGameCubeButton(int pad_num, int button , int value);
void setGameCubeAxis(int pad_num, int button , float value);
void init_Callback();

//static gc_pad GameCubePads[4];

typedef struct
{
//    keymap wiimote_keymap[54] = {
//        {PVWiiMoteButtonLeft, 0},
//        {PVWiiMoteButtonRight, 0},
//        {PVWiiMoteButtonDown, 0},
//        {PVWiiMoteButtonUp, 0},
//        {PVWiiMoteButtonA, 0},
//        {PVWiiMoteButtonB, 0},
//        {PVWiiMoteButton1, 0},
//        {PVWiiMoteButton2, 0},
//        {PVWiiMoteButtonPlus, 0},
//        {PVWiiMoteButtonMinus, 0},
//        {PVWiiMoteButtonHome, 0},
//        {PVWiiMoteTiltForward, 0},
//        {PVWiiMoteTiltBackward, 0},
//        {PVWiiMoteTiltLeft, 0},
//        {PVWiiMoteTiltRight, 0},
//        {PVWiiMoteShake, 0},
//        {PVWiiMoteSwingUp, 0},
//        {PVWiiMoteSwingDown, 0},
//        {PVWiiMoteSwingLeft, 0},
//        {PVWiiMoteSwingRight, 0},
//        {PVWiiMoteSwingForward, 0},
//        {PVWiiMoteSwingBackward, 0},
//        {PVWiiNunchukAnalogUp, 0},
//        {PVWiiNunchukAnalogDown, 0},
//        {PVWiiNunchukAnalogLeft, 0},
//        {PVWiiNunchukAnalogRight, 0},
//        {PVWiiNunchukButtonC, 0},
//        {PVWiiNunchukButtonZ, 0},
//        {PVWiiNunchukShake, 0},
//        {PVWiiClassicButtonUp, 0},
//        {PVWiiClassicButtonDown, 0},
//        {PVWiiClassicButtonLeft, 0},
//        {PVWiiClassicButtonRight, 0},
//        {PVWiiClassicAnalogLUp, 0},
//        {PVWiiClassicAnalogLDown, 0},
//        {PVWiiClassicAnalogLLeft, 0},
//        {PVWiiClassicAnalogLRight, 0},
//        {PVWiiClassicAnalogRUp, 0},
//        {PVWiiClassicAnalogRDown, 0},
//        {PVWiiClassicAnalogRLeft, 0},
//        {PVWiiClassicAnalogRRight, 0},
//        {PVWiiClassicButtonA, 0},
//        {PVWiiClassicButtonB, 0},
//        {PVWiiClassicButtonX, 0},
//        {PVWiiClassicButtonY, 0},
//        {PVWiiClassicButtonL, 0},
//        {PVWiiClassicButtonR, 0},
//        {PVWiiClassicButtonZl, 0},
//        {PVWiiClassicButtonZr, 0},
//        {PVWiiClassicButtonStart, 0},
//        {PVWiiClassicButtonSelect, 0},
//        {PVWiiClassicButtonHome, 0},
//        {PVWiimoteSideways, 0},
//        {PVWiimoteUpright, 0},
//    };
//    
//    PVWiiConType wiimoteType;
//    ControlState dx, dy;
} wii_remote;

void setWiiButton(int pad_num, int button , int value);
void setWiiAxis(int pad_num, int button , float value);

static wii_remote WiiRemotes[4];


