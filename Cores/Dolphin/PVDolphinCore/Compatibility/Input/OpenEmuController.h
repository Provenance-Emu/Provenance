typedef struct
{
    int openemuButton;
    int value;
} keymap;

typedef struct
{
    keymap gc_pad_keymap[22] = {
        {OEGCButtonUp, 0},
        {OEGCButtonDown, 0},
        {OEGCButtonLeft, 0},
        {OEGCButtonRight, 0},
        {OEGCAnalogUp, 0},
        {OEGCAnalogDown, 0},
        {OEGCAnalogLeft, 0},
        {OEGCAnalogRight,  0},
        {OEGCAnalogCUp,  0},
        {OEGCAnalogCDown, 0},
        {OEGCAnalogCLeft, 0},
        {OEGCAnalogCRight,  0},
        {OEGCButtonA,  0},
        {OEGCButtonB, 0},
        {OEGCButtonX, 0},
        {OEGCButtonY, 0},
        {OEGCButtonL, 0},
        {OEGCButtonR, 0},
        {OEGCButtonZ, 0},
        {OEGCButtonStart, 0},
        {OEGCDigitalL, 0},
        {OEGCDigitalR, 0},
    };
} gc_pad;


void setGameCubeButton(int pad_num, int button , int value);
void setGameCubeAxis(int pad_num, int button , float value);
void init_Callback();

static gc_pad GameCubePads[4];

typedef struct
{
    keymap wiimote_keymap[54] = {
        {OEWiiMoteButtonLeft, 0},
        {OEWiiMoteButtonRight, 0},
        {OEWiiMoteButtonDown, 0},
        {OEWiiMoteButtonUp, 0},
        {OEWiiMoteButtonA, 0},
        {OEWiiMoteButtonB, 0},
        {OEWiiMoteButton1, 0},
        {OEWiiMoteButton2, 0},
        {OEWiiMoteButtonPlus, 0},
        {OEWiiMoteButtonMinus, 0},
        {OEWiiMoteButtonHome, 0},
        {OEWiiMoteTiltForward, 0},
        {OEWiiMoteTiltBackward, 0},
        {OEWiiMoteTiltLeft, 0},
        {OEWiiMoteTiltRight, 0},
        {OEWiiMoteShake, 0},
        {OEWiiMoteSwingUp, 0},
        {OEWiiMoteSwingDown, 0},
        {OEWiiMoteSwingLeft, 0},
        {OEWiiMoteSwingRight, 0},
        {OEWiiMoteSwingForward, 0},
        {OEWiiMoteSwingBackward, 0},
        {OEWiiNunchukAnalogUp, 0},
        {OEWiiNunchukAnalogDown, 0},
        {OEWiiNunchukAnalogLeft, 0},
        {OEWiiNunchukAnalogRight, 0},
        {OEWiiNunchukButtonC, 0},
        {OEWiiNunchukButtonZ, 0},
        {OEWiiNunchukShake, 0},
        {OEWiiClassicButtonUp, 0},
        {OEWiiClassicButtonDown, 0},
        {OEWiiClassicButtonLeft, 0},
        {OEWiiClassicButtonRight, 0},
        {OEWiiClassicAnalogLUp, 0},
        {OEWiiClassicAnalogLDown, 0},
        {OEWiiClassicAnalogLLeft, 0},
        {OEWiiClassicAnalogLRight, 0},
        {OEWiiClassicAnalogRUp, 0},
        {OEWiiClassicAnalogRDown, 0},
        {OEWiiClassicAnalogRLeft, 0},
        {OEWiiClassicAnalogRRight, 0},
        {OEWiiClassicButtonA, 0},
        {OEWiiClassicButtonB, 0},
        {OEWiiClassicButtonX, 0},
        {OEWiiClassicButtonY, 0},
        {OEWiiClassicButtonL, 0},
        {OEWiiClassicButtonR, 0},
        {OEWiiClassicButtonZl, 0},
        {OEWiiClassicButtonZr, 0},
        {OEWiiClassicButtonStart, 0},
        {OEWiiClassicButtonSelect, 0},
        {OEWiiClassicButtonHome, 0},
        {OEWiimoteSideways, 0},
        {OEWiimoteUpright, 0},
    };
    
    OEWiiConType wiimoteType;
    ControlState dx, dy;
} wii_remote;

void setWiiButton(int pad_num, int button , int value);
void setWiiAxis(int pad_num, int button , float value);

static wii_remote WiiRemotes[4];


