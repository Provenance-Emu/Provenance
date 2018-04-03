//
// This file should only be included *ONCE* from drivers/input.cpp!!!
//

#define MKDEF(sc) 	 "keyboard 0x0 " KBD_SCANCODE_STRING(sc)
#define MKDEF2(sca, scb) "keyboard 0x0 " KBD_SCANCODE_STRING(sca) " || " "keyboard 0x0 " KBD_SCANCODE_STRING(scb)

#define MKMOUSEB(b) 	 "mouse 0x0 button_" b
#define MKMOUSECURSOR(a) "mouse 0x0 cursor_" a "-+"

#define MKMOUSEAXRELPAIR(a) "mouse 0x0 rel_" a "-", "mouse 0x0 rel_" a "+"

static const char* const NESGamePadConfig[] =
{
        /* Gamepad 1 */
         MKDEF(KP_3), MKDEF(KP_2), MKDEF(TAB), MKDEF(RETURN), MKDEF(W),MKDEF(S),
                MKDEF(A), MKDEF(D)
};

static const char* const GBPadConfig[] =
{
         MKDEF(KP_3), MKDEF(KP_2), MKDEF(TAB), MKDEF(RETURN), MKDEF(D),MKDEF(A),
                MKDEF(W), MKDEF(S)
};

static const char* const GBAPadConfig[] =
{
         MKDEF(KP_3), MKDEF(KP_2), MKDEF(TAB), MKDEF(RETURN), MKDEF(D),MKDEF(A),
                MKDEF(W), MKDEF(S), MKDEF(KP_6), MKDEF(KP_5)
};

static const char* const PCFXPadConfig[] =
{
        /* Gamepad 1 */
        MKDEF(KP_3), MKDEF(KP_2), MKDEF(KP_1), MKDEF(KP_4), MKDEF(KP_5), MKDEF(KP_6), MKDEF(TAB), MKDEF(RETURN),
        MKDEF(W), MKDEF(D), MKDEF(S), MKDEF(A),
	MKDEF(KP_8), MKDEF(KP_9),
};

static const char* const PCEPadConfig[] = 
{
        /* Gamepad 1 */
        MKDEF(KP_3), MKDEF(KP_2), MKDEF(TAB), MKDEF(RETURN), MKDEF(W), MKDEF(D), MKDEF(S), MKDEF(A),

        // Extra 4 buttons on 6-button pad
        MKDEF(KP_1), MKDEF(KP_4), MKDEF(KP_5), MKDEF(KP_6),

        // ..and special 2/6 mode select
        MKDEF(M),
};

static const char* const LynxPadConfig[] =
{
        // A, B, Option 2, Option 1, Left, Right, Up, Down, Pause
         MKDEF(KP_3), MKDEF(KP_2), MKDEF(KP_1), MKDEF(KP_7), MKDEF(A),MKDEF(D),
                MKDEF(W), MKDEF(S), MKDEF(RETURN)
};

static const char* const NGPPadConfig[] =
{
        // Up, down, left, right, a(inner), b(outer), option
        MKDEF(W), MKDEF(S), MKDEF(A), MKDEF(D), MKDEF(KP_2), MKDEF(KP_3), MKDEF(RETURN)
};

static const char* const WSwanPadConfig[] =
{
        // Up, right, down, left,
        // up-y, right-y, down-y, left-y,
	//  start, a(outer), b(inner)
        MKDEF(W), MKDEF(D), MKDEF(S), MKDEF(A), 
	MKDEF(UP), MKDEF(RIGHT), MKDEF(DOWN), MKDEF(LEFT),
	MKDEF(RETURN), MKDEF(KP_3), MKDEF(KP_2)
};

static const char* const WSwanPadRAAConfig[] =
{
        // Up, right, down, left,
        // up-y, right-y, down-y, left-y,
	// a', a, b, b'
	// start
        MKDEF(W), MKDEF(D), MKDEF(S), MKDEF(A), 
	MKDEF(UP), MKDEF(RIGHT), MKDEF(DOWN), MKDEF(LEFT),

	MKDEF(KP_6),
	MKDEF(KP_3),
	MKDEF(KP_2),
	MKDEF(KP_5),

	MKDEF(RETURN)
};


static const char* const PowerPadConfig[] =
{
 MKDEF(O),MKDEF(P),MKDEF(LEFTBRACKET),MKDEF(RIGHTBRACKET),
 MKDEF(K),MKDEF(L),MKDEF(SEMICOLON),MKDEF(APOSTROPHE),
 MKDEF(M),MKDEF(COMMA),MKDEF(PERIOD),MKDEF(SLASH)
};

static const char* const fkbmap[] =
{
 MKDEF(F1),MKDEF(F2),MKDEF(F3),MKDEF(F4),MKDEF(F5),MKDEF(F6),MKDEF(F7),MKDEF(F8),
 MKDEF(1),MKDEF(2),MKDEF(3),MKDEF(4),MKDEF(5),MKDEF(6),MKDEF(7),MKDEF(8),MKDEF(9),MKDEF(0),MKDEF(MINUS),MKDEF(EQUALS),MKDEF(BACKSLASH),MKDEF(BACKSPACE),
 MKDEF(ESCAPE),MKDEF(Q),MKDEF(W),MKDEF(E),MKDEF(R),MKDEF(T),MKDEF(Y),MKDEF(U),MKDEF(I),MKDEF(O),MKDEF(P),MKDEF(GRAVE),MKDEF(LEFTBRACKET),MKDEF(RETURN),
 MKDEF(LCTRL),MKDEF(A),MKDEF(S),MKDEF(D),MKDEF(F),MKDEF(G),MKDEF(H),MKDEF(J),MKDEF(K),MKDEF(L),MKDEF(SEMICOLON),MKDEF(APOSTROPHE),MKDEF(RIGHTBRACKET),MKDEF(INSERT),
 MKDEF(LSHIFT),MKDEF(Z),MKDEF(X),MKDEF(C),MKDEF(V),MKDEF(B),MKDEF(N),MKDEF(M),MKDEF(COMMA),MKDEF(PERIOD),MKDEF(SLASH),MKDEF(RALT),MKDEF(RSHIFT),MKDEF(LALT),MKDEF(SPACE),
 MKDEF(DELETE),MKDEF(END),MKDEF(PAGEDOWN),MKDEF(UP),MKDEF(LEFT),MKDEF(RIGHT),MKDEF(DOWN)
};

static const char* const HyperShotButtons[] =
{
 MKDEF(Q),MKDEF(W),MKDEF(E),MKDEF(R)
};

static const char* const MahjongButtons[] =
{
 MKDEF(Q),MKDEF(W),MKDEF(E),MKDEF(R),MKDEF(T),
 MKDEF(A),MKDEF(S),MKDEF(D),MKDEF(F),MKDEF(G),MKDEF(H),MKDEF(J),MKDEF(K),MKDEF(L),
 MKDEF(Z),MKDEF(X),MKDEF(C),MKDEF(V),MKDEF(B),MKDEF(N),MKDEF(M)
};

static const char* const PartyTapButtons[] =
{
 MKDEF(Q),MKDEF(W),MKDEF(E),MKDEF(R),MKDEF(T),MKDEF(Y)
};

static const char* const FTrainerButtons[] =
{
 MKDEF(O),MKDEF(P),MKDEF(LEFTBRACKET),
 MKDEF(RIGHTBRACKET),MKDEF(K),MKDEF(L),MKDEF(SEMICOLON),
 MKDEF(APOSTROPHE),
 MKDEF(M),MKDEF(COMMA),MKDEF(PERIOD),MKDEF(SLASH)
};

static const char* const OekaKidsConfig[] =
{
 MKMOUSECURSOR("x"),
 MKMOUSECURSOR("y"),

 MKMOUSEB("left"),
};

static const char* const ArkanoidConfig[] =
{
 MKMOUSECURSOR("x"),

 MKMOUSEB("left"),
};

static const char* const ShadowConfig[] =
{
 MKMOUSECURSOR("x"),
 MKMOUSECURSOR("y"),

 MKMOUSEB("left"),
 MKMOUSEB("right"),
};


static const char* const NESZapperConfig[] =
{
 MKMOUSECURSOR("x"),
 MKMOUSECURSOR("y"),

 MKMOUSEB("left"),
 MKMOUSEB("right"),
};

static const char* const PCEMouseConfig[] =
{
 MKMOUSEAXRELPAIR("x"),
 MKMOUSEAXRELPAIR("y"),
 MKMOUSEB("right"),
 MKMOUSEB("left"),
 MKDEF(TAB),
 MKDEF(RETURN)
};

static const char* const PCEFastMouseConfig[] =
{
 MKMOUSEAXRELPAIR("x"),
 MKMOUSEAXRELPAIR("y"),
 MKMOUSEB("right"),
 MKMOUSEB("left"),
 MKDEF(TAB),
 MKDEF(RETURN)
};


static const char* const PCFXMouseConfig[] =
{
 MKMOUSEAXRELPAIR("x"),
 MKMOUSEAXRELPAIR("y"),
 MKMOUSEB("left"),
 MKMOUSEB("right"),
};

static const char* const SMSPadConfig[] =
{
        /* Gamepad 1 */
	MKDEF(W), MKDEF(S), MKDEF(A), MKDEF(D), MKDEF(KP_2), MKDEF(KP_3), MKDEF(RETURN)
};

static const char* const GGPadConfig[] =
{
         MKDEF(W), MKDEF(S), MKDEF(A), MKDEF(D), MKDEF(KP_2), MKDEF(KP_3), MKDEF(RETURN)
};

static const char* const TsushinKBConfig[] =
{
 // 0
 MKDEF(KP_0),
 MKDEF(KP_1),
 MKDEF(KP_2),
 MKDEF(KP_3),
 MKDEF(KP_4),
 MKDEF(KP_5),
 MKDEF(KP_6),

// 1
 MKDEF(KP_8),
 MKDEF(KP_9),
 MKDEF(KP_MULTIPLY),		// Keypad Multiply
 MKDEF(KP_PLUS),			// Keypad Plus
 MKDEF(KP_EQUALS),			// Keypad Equals
 MKDEF(UNKNOWN), // KP_COMMA	// Keypad Comma
 MKDEF(KP_PERIOD),			// Keypad Period

// 2
 MKDEF(GRAVE),		// @
 MKDEF(A),
 MKDEF(B),
 MKDEF(C),
 MKDEF(D),
 MKDEF(E),
 MKDEF(F),

// 3
 MKDEF(H),
 MKDEF(I),
 MKDEF(J),
 MKDEF(K),
 MKDEF(L),
 MKDEF(M),
 MKDEF(N),

// 4
 MKDEF(P),
 MKDEF(Q),
 MKDEF(R),
 MKDEF(S),
 MKDEF(T),
 MKDEF(U),
 MKDEF(V),

// 5
 MKDEF(X),
 MKDEF(Y),
 MKDEF(Z),
 MKDEF(LEFTBRACKET),	// Left bracket
 MKDEF(EQUALS),		// Yen
 MKDEF(RIGHTBRACKET),	// Right bracket
 MKDEF(EQUALS),		// Caret

// 6
 MKDEF(0),
 MKDEF(1),
 MKDEF(2),
 MKDEF(3),
 MKDEF(4),
 MKDEF(5),
 MKDEF(6),

// 7
 MKDEF(8),
 MKDEF(9),
 MKDEF(APOSTROPHE),		// Colon
 MKDEF(SEMICOLON),		// Semicolon
 MKDEF(COMMA),		// Comma
 MKDEF(PERIOD),		// Period
 MKDEF(SLASH),		// Slash

// 8
 MKDEF(HOME),		// HOME CLEAR
 MKDEF(UP),
 MKDEF(RIGHT),
 //MKDEF(UNKNOWN),
 MKDEF(UNKNOWN),		// GRPH
 MKDEF(LGUI),		// カナ
 //MKDEF(UNKNOWN),

// 9
 MKDEF(PAUSE),		// STOP
 MKDEF(F1),
 MKDEF(F2),
 MKDEF(F3),
 MKDEF(F4),
 MKDEF(F5),
 MKDEF(SPACE),

 // A
 MKDEF(TAB),
 MKDEF(DOWN),
 MKDEF(LEFT),
 MKDEF(END),		// HELP
 MKDEF(PRINTSCREEN),	// COPY
 MKDEF(KP_MINUS),
 MKDEF(KP_DIVIDE),

// B
 MKDEF(PAGEDOWN),		// ROLL DOWN
 MKDEF(PAGEUP),		// ROLL UP
 //MKDEF(UNKNOWN),
 //MKDEF(UNKNOWN),
 MKDEF(O),
 MKDEF(UNKNOWN),	// TODO: Underscore
 MKDEF(G),

// C
 MKDEF(F6),
 MKDEF(F7),
 MKDEF(F8),
 MKDEF(F9),
 MKDEF(F10),
 MKDEF(BACKSPACE),
 MKDEF(INSERT),

// D
 MKDEF(RALT),		// 変換
 MKDEF(LALT),		// 決定
 MKDEF(RGUI),		// PC
 MKDEF(RCTRL),		// 変換
 MKDEF(LCTRL),		// CTRL
 MKDEF(KP_7),
 MKDEF(W),

// E
 MKDEF(RETURN),
 MKDEF(KP_ENTER),
 MKDEF(LSHIFT),
 MKDEF(RSHIFT),
 MKDEF(CAPSLOCK),
 MKDEF(DELETE),
 MKDEF(ESCAPE),

// F
 //MKDEF(UNKNOWN),
 //MKDEF(UNKNOWN),
 //MKDEF(UNKNOWN),
 //MKDEF(UNKNOWN),
 //MKDEF(UNKNOWN),
 MKDEF(MINUS),		// Minus
 MKDEF(7),			// 7
};


static const char* const MMPlayInputConfig[] =
{
	MKDEF(P),
	MKDEF(LEFT),
	MKDEF(RIGHT),
	MKDEF(DOWN),
	MKDEF(UP),
};

static const char* const CDPlayInputConfig[] =
{
        MKDEF(SPACE),
	MKDEF(RETURN),
        MKDEF(RIGHT),
	MKDEF(LEFT),
        MKDEF(UP),
	MKDEF(DOWN),
	MKDEF(PAGEUP),
	MKDEF(PAGEDOWN),
};


static const char* const MDPad3Config[] =
{
 MKDEF(W), MKDEF(S), MKDEF(A), MKDEF(D), MKDEF(KP_2), MKDEF(KP_3), MKDEF(KP_1), MKDEF(RETURN)
};

static const char* const MDPad6Config[] =
{
 MKDEF(W), MKDEF(S), MKDEF(A), MKDEF(D), MKDEF(KP_2), MKDEF(KP_3), MKDEF(KP_1), MKDEF(RETURN), MKDEF(KP_6), MKDEF(KP_5), MKDEF(KP_4), MKDEF(M)
};

static const char* const MDMegaMouseConfig[] =
{
 MKMOUSEAXRELPAIR("x"),
 MKMOUSEAXRELPAIR("y"),
 MKMOUSEB("left"),
 MKMOUSEB("right"),
 MKMOUSEB("middle"),
 MKDEF(RETURN),
};

static const char* const SSPadConfig[] =
{
 MKDEF(KP_6),
 MKDEF(KP_5),
 MKDEF(KP_4),
 MKDEF(KP_9),

 MKDEF(W),
 MKDEF(S),
 MKDEF(A),
 MKDEF(D),

 MKDEF(KP_2),
 MKDEF(KP_3),
 MKDEF(KP_1),
 MKDEF(RETURN),

 MKDEF(KP_7),

};

static const char* const SSMouseConfig[] =
{
 MKMOUSEAXRELPAIR("x"),
 MKMOUSEAXRELPAIR("y"),
 MKMOUSEB("left"),
 MKMOUSEB("right"),
 MKMOUSEB("middle"),
 MKDEF(RETURN),
};

static const char* const SSGunConfig[] =
{
 MKMOUSECURSOR("x"),
 MKMOUSECURSOR("y"),

 MKMOUSEB("left"),
 MKMOUSEB("middle"),
 MKMOUSEB("right"),
};


static const char* const SSKeyboardConfig[] =
{
 MKDEF(F9),
 MKDEF(F5),
 MKDEF(F3),
 MKDEF(F1),
 MKDEF(F2),
 MKDEF(F12),
 MKDEF(F10),
 MKDEF(F8),
 MKDEF(F6),
 MKDEF(F4),
 MKDEF(TAB),
 MKDEF(GRAVE),

 MKDEF(LALT),
 MKDEF(LSHIFT),
 MKDEF(LCTRL),
 MKDEF(Q),
 MKDEF(1),
 MKDEF(RALT),
 MKDEF(RCTRL),
 MKDEF(KP_ENTER),
 MKDEF(Z),
 MKDEF(S),
 MKDEF(A),
 MKDEF(W),
 MKDEF(2),

 MKDEF(C),
 MKDEF(X),
 MKDEF(D),
 MKDEF(E),
 MKDEF(4),
 MKDEF(3),
 MKDEF(SPACE),
 MKDEF(V),
 MKDEF(F),
 MKDEF(T),
 MKDEF(R),
 MKDEF(5),

 MKDEF(N),
 MKDEF(B),
 MKDEF(H),
 MKDEF(G),
 MKDEF(Y),
 MKDEF(6),
 MKDEF(M),
 MKDEF(J),
 MKDEF(U),
 MKDEF(7),
 MKDEF(8),

 MKDEF(COMMA),
 MKDEF(K),
 MKDEF(I),
 MKDEF(O),
 MKDEF(0),
 MKDEF(9),
 MKDEF(PERIOD),
 MKDEF(SLASH),
 MKDEF(L),
 MKDEF(SEMICOLON),
 MKDEF(P),
 MKDEF(MINUS),

 MKDEF(APOSTROPHE),
 MKDEF(LEFTBRACKET),
 MKDEF(EQUALS),
 MKDEF(CAPSLOCK),
 MKDEF(RSHIFT),
 MKDEF(RETURN),
 MKDEF(RIGHTBRACKET),
 MKDEF2(BACKSLASH, INTERNATIONAL1),

 MKDEF(BACKSPACE),
 MKDEF(KP_1),
 MKDEF(KP_4),
 MKDEF(KP_7),

 MKDEF(KP_0),
 MKDEF(KP_PERIOD),
 MKDEF(KP_2),
 MKDEF(KP_5),
 MKDEF(KP_6),
 MKDEF(KP_8),
 MKDEF(ESCAPE),
 MKDEF(NUMLOCKCLEAR),
 MKDEF(F11),
 MKDEF(KP_PLUS),
 MKDEF(KP_3),
 MKDEF(KP_MINUS),
 MKDEF(KP_MULTIPLY),
 MKDEF(KP_9),
 MKDEF(SCROLLLOCK),

 MKDEF(KP_DIVIDE),
 MKDEF(INSERT),
 MKDEF(PAUSE),
 MKDEF(F7),
 MKDEF(PRINTSCREEN),
 MKDEF(DELETE),
 MKDEF(LEFT),
 MKDEF(HOME),
 MKDEF(END),
 MKDEF(UP),
 MKDEF(DOWN),
 MKDEF(PAGEUP),
 MKDEF(PAGEDOWN),
 MKDEF(RIGHT),
};


static const char* const SSJPKeyboardConfig[] =
{
 MKDEF(F9),
 MKDEF(F5),
 MKDEF(F3),
 MKDEF(F1),
 MKDEF(F2),
 MKDEF(F12),
 MKDEF(F10),
 MKDEF(F8),
 MKDEF(F6),
 MKDEF(F4),
 MKDEF(TAB),
 MKDEF(GRAVE),

 MKDEF(LALT),
 MKDEF(LSHIFT),
 MKDEF(INTERNATIONAL2),
 MKDEF(LCTRL),
 MKDEF(Q),
 MKDEF(1),
 MKDEF(RALT),
 MKDEF(RCTRL),
 MKDEF(Z),
 MKDEF(S),
 MKDEF(A),
 MKDEF(W),
 MKDEF(2),

 MKDEF(C),
 MKDEF(X),
 MKDEF(D),
 MKDEF(E),
 MKDEF(4),
 MKDEF(3),
 MKDEF(SPACE),
 MKDEF(V),
 MKDEF(F),
 MKDEF(T),
 MKDEF(R),
 MKDEF(5),

 MKDEF(N),
 MKDEF(B),
 MKDEF(H),
 MKDEF(G),
 MKDEF(Y),
 MKDEF(6),
 MKDEF(M),
 MKDEF(J),
 MKDEF(U),
 MKDEF(7),
 MKDEF(8),

 MKDEF(COMMA),
 MKDEF(K),
 MKDEF(I),
 MKDEF(O),
 MKDEF(0),
 MKDEF(9),
 MKDEF(PERIOD),
 MKDEF(SLASH),
 MKDEF(L),
 MKDEF(SEMICOLON),
 MKDEF(P),
 MKDEF(MINUS),

 MKDEF(INTERNATIONAL1),
 MKDEF(APOSTROPHE),
 MKDEF(LEFTBRACKET),
 MKDEF(EQUALS),
 MKDEF(CAPSLOCK),
 MKDEF(RSHIFT),
 MKDEF(RETURN),
 MKDEF(RIGHTBRACKET),
 MKDEF(BACKSLASH),

 MKDEF(INTERNATIONAL4),
 MKDEF(BACKSPACE),
 MKDEF(INTERNATIONAL5),
 MKDEF(INTERNATIONAL3),

 MKDEF(ESCAPE),
 MKDEF(F11),
 MKDEF(SCROLLLOCK),

 MKDEF(INSERT),
 MKDEF2(PAUSE, NUMLOCKCLEAR),	// JP Saturn keyboard pause key acts like a normal key, so provide options for keyboards or keyboard interfaces with lousy pause key support
 MKDEF(F7),
 MKDEF(PRINTSCREEN),
 MKDEF(DELETE),
 MKDEF(LEFT),
 MKDEF(HOME),
 MKDEF(END),
 MKDEF(UP),
 MKDEF(DOWN),
 MKDEF(PAGEUP),
 MKDEF(PAGEDOWN),
 MKDEF(RIGHT),
};


static const char* const SNESPadConfig[] =
{
 MKDEF(KP_2),
 MKDEF(KP_4),
 MKDEF(TAB),
 MKDEF(RETURN),
 MKDEF(W),
 MKDEF(S),
 MKDEF(A),
 MKDEF(D),
 MKDEF(KP_6),
 MKDEF(KP_8),
 MKDEF(KP_7),
 MKDEF(KP_9),
};


static const char* const SNESMouseConfig[] =
{
 MKMOUSEAXRELPAIR("x"),
 MKMOUSEAXRELPAIR("y"),
 MKMOUSEB("left"),
 MKMOUSEB("right"),
};

static const char* const SNESSuperScopeConfig[] =
{
 MKMOUSECURSOR("x"),
 MKMOUSECURSOR("y"),

 MKMOUSEB("left"),	// Trigger
 MKDEF(SPACE),			// Away trigger
 MKMOUSEB("middle"),	// Pause
 MKDEF(END),			// Turbo
 MKMOUSEB("right"),	// Cursor
};

static const char* const PSXPadConfig[] =
{
 MKDEF(TAB),
 MKDEF(RETURN),
 MKDEF(W),
 MKDEF(D),
 MKDEF(S),
 MKDEF(A),

 MKDEF(KP_7),
 MKDEF(KP_9),
 MKDEF(KP_1),
 MKDEF(KP_3),

 MKDEF(KP_8),
 MKDEF(KP_6),
 MKDEF(KP_2),
 MKDEF(KP_4),
};

static const char* const PSXDancePadConfig[] =
{
 MKDEF(KP_DIVIDE),
 MKDEF(KP_MULTIPLY),
 MKDEF(KP_8),
 MKDEF(KP_6),
 MKDEF(KP_2),
 MKDEF(KP_4),

 MKDEF(KP_1),
 MKDEF(KP_9),
 MKDEF(KP_7),
 MKDEF(KP_3),
};

static const char* const PSXMouseConfig[] =
{
 MKMOUSEAXRELPAIR("x"),
 MKMOUSEAXRELPAIR("y"),
 MKMOUSEB("right"),
 MKMOUSEB("left"),
};

static const char* const PSXGunConConfig[] =
{
 MKMOUSECURSOR("x"),
 MKMOUSECURSOR("y"),

 MKMOUSEB("left"),
 MKMOUSEB("right"),
 MKMOUSEB("middle"),
 MKDEF(SPACE)
};

static const char* const PSXJustifierConfig[] =
{
 MKMOUSECURSOR("x"),
 MKMOUSECURSOR("y"),

 MKMOUSEB("left"),
 MKMOUSEB("right"),
 MKMOUSEB("middle"),
 MKDEF(SPACE)
};

#if 0
static ButtConfig VBPadConfig[14] =
{


 MKDEF(I),	// RPad, Up
 MKDEF(L), // RPad, Right

 MKDEF(F), // LPad, Right
 MKDEF(S), // LPad, Left
 MKDEF(D), // LPad, Down
 MKDEF(E), // LPad, Up
};
#endif

struct cstrcomp
{
 bool operator()(const char * const &a, const char * const &b) const
 {
  return(strcmp(a, b) < 0);
 }
};

const std::map<const char*, DefaultSettingsMeow, cstrcomp> defset =
{
 #define DPDC(a, b) { a, { b, sizeof(b) / sizeof(b[0]) } }
 DPDC("nes.input.port1.gamepad", NESGamePadConfig),

 DPDC("nes.input.port1.powerpada", PowerPadConfig),
 DPDC("nes.input.port2.powerpada", PowerPadConfig),
 DPDC("nes.input.port1.powerpadb", PowerPadConfig),
 DPDC("nes.input.port2.powerpadb", PowerPadConfig),

 DPDC("nes.input.port1.zapper", NESZapperConfig),
 DPDC("nes.input.port2.zapper", NESZapperConfig),

 DPDC("nes.input.fcexp.fkb", fkbmap),
 DPDC("nes.input.fcexp.mahjong", MahjongButtons),
 DPDC("nes.input.fcexp.ftrainera", FTrainerButtons),
 DPDC("nes.input.fcexp.ftrainerb", FTrainerButtons),

 DPDC("nes.input.fcexp.hypershot", HyperShotButtons),
 DPDC("nes.input.fcexp.partytap", PartyTapButtons),

 DPDC("nes.input.fcexp.oekakids", OekaKidsConfig),

 DPDC("nes.input.fcexp.shadow", ShadowConfig),

 DPDC("nes.input.port1.arkanoid", ArkanoidConfig),
 DPDC("nes.input.port2.arkanoid", ArkanoidConfig),
 DPDC("nes.input.port3.arkanoid", ArkanoidConfig),
 DPDC("nes.input.port4.arkanoid", ArkanoidConfig),
 DPDC("nes.input.fcexp.arkanoid", ArkanoidConfig),
 DPDC("lynx.input.builtin.gamepad", LynxPadConfig),
 DPDC("gb.input.builtin.gamepad", GBPadConfig),
 DPDC("gba.input.builtin.gamepad", GBAPadConfig),
 DPDC("ngp.input.builtin.gamepad", NGPPadConfig),
 DPDC("wswan.input.builtin.gamepad", WSwanPadConfig),
 DPDC("wswan.input.builtin.gamepadraa", WSwanPadRAAConfig),

 //
 DPDC("pce.input.port1.gamepad", PCEPadConfig),

 DPDC("pce.input.port1.mouse", PCEMouseConfig),
 DPDC("pce.input.port2.mouse", PCEMouseConfig),
 DPDC("pce.input.port3.mouse", PCEMouseConfig),
 DPDC("pce.input.port4.mouse", PCEMouseConfig),
 DPDC("pce.input.port5.mouse", PCEMouseConfig),

 DPDC("pce.input.port1.tsushinkb", TsushinKBConfig),
 //
 DPDC("pce_fast.input.port1.mouse", PCEFastMouseConfig),
 DPDC("pce_fast.input.port2.mouse", PCEFastMouseConfig),
 DPDC("pce_fast.input.port3.mouse", PCEFastMouseConfig),
 DPDC("pce_fast.input.port4.mouse", PCEFastMouseConfig),
 DPDC("pce_fast.input.port5.mouse", PCEFastMouseConfig),
 //
 DPDC("pcfx.input.port1.gamepad", PCFXPadConfig),

 DPDC("pcfx.input.port1.mouse", PCFXMouseConfig),
 DPDC("pcfx.input.port2.mouse", PCFXMouseConfig),
 DPDC("pcfx.input.port3.mouse", PCFXMouseConfig),
 DPDC("pcfx.input.port4.mouse", PCFXMouseConfig),
 DPDC("pcfx.input.port5.mouse", PCFXMouseConfig),
 DPDC("pcfx.input.port6.mouse", PCFXMouseConfig),
 DPDC("pcfx.input.port7.mouse", PCFXMouseConfig),
 DPDC("pcfx.input.port8.mouse", PCFXMouseConfig),

 //
 DPDC("sms.input.port1.gamepad", SMSPadConfig),

 //
 DPDC("gg.input.builtin.gamepad", GGPadConfig),


 //
 DPDC("md.input.port1.gamepad", MDPad3Config),

 DPDC("md.input.port1.gamepad6", MDPad6Config),

 DPDC("md.input.port1.megamouse", MDMegaMouseConfig),
 DPDC("md.input.port2.megamouse", MDMegaMouseConfig),
 DPDC("md.input.port3.megamouse", MDMegaMouseConfig),
 DPDC("md.input.port4.megamouse", MDMegaMouseConfig),
 DPDC("md.input.port5.megamouse", MDMegaMouseConfig),
 DPDC("md.input.port6.megamouse", MDMegaMouseConfig),
 DPDC("md.input.port7.megamouse", MDMegaMouseConfig),
 DPDC("md.input.port8.megamouse", MDMegaMouseConfig),


 //
 DPDC("snes.input.port1.gamepad", SNESPadConfig),
 DPDC("snes.input.port1.mouse", SNESMouseConfig),
 DPDC("snes.input.port2.mouse", SNESMouseConfig),
 DPDC("snes.input.port2.superscope", SNESSuperScopeConfig),

 //
 DPDC("snes_faust.input.port1.gamepad", SNESPadConfig),

 //
 DPDC("psx.input.port1.gamepad", PSXPadConfig),

 DPDC("psx.input.port1.dancepad", PSXDancePadConfig),

 DPDC("psx.input.port1.mouse", PSXMouseConfig),
 DPDC("psx.input.port2.mouse", PSXMouseConfig),
 DPDC("psx.input.port3.mouse", PSXMouseConfig),
 DPDC("psx.input.port4.mouse", PSXMouseConfig),
 DPDC("psx.input.port5.mouse", PSXMouseConfig),
 DPDC("psx.input.port6.mouse", PSXMouseConfig),
 DPDC("psx.input.port7.mouse", PSXMouseConfig),
 DPDC("psx.input.port8.mouse", PSXMouseConfig),

 DPDC("psx.input.port1.guncon", PSXGunConConfig),
 DPDC("psx.input.port2.guncon", PSXGunConConfig),
 DPDC("psx.input.port3.guncon", PSXGunConConfig),
 DPDC("psx.input.port4.guncon", PSXGunConConfig),
 DPDC("psx.input.port5.guncon", PSXGunConConfig),
 DPDC("psx.input.port6.guncon", PSXGunConConfig),
 DPDC("psx.input.port7.guncon", PSXGunConConfig),
 DPDC("psx.input.port8.guncon", PSXGunConConfig),

 DPDC("psx.input.port1.justifier", PSXJustifierConfig),
 DPDC("psx.input.port2.justifier", PSXJustifierConfig),

 //{ "vb.input.builtin.gamepad", VBPadConfig),

 //
 DPDC("ss.input.port1.gamepad", SSPadConfig),

 DPDC("ss.input.port1.mouse", SSMouseConfig),
 DPDC("ss.input.port2.mouse", SSMouseConfig),
 DPDC("ss.input.port3.mouse", SSMouseConfig),
 DPDC("ss.input.port4.mouse", SSMouseConfig),
 DPDC("ss.input.port5.mouse", SSMouseConfig),
 DPDC("ss.input.port6.mouse", SSMouseConfig),
 DPDC("ss.input.port7.mouse", SSMouseConfig),
 DPDC("ss.input.port8.mouse", SSMouseConfig),
 DPDC("ss.input.port9.mouse", SSMouseConfig),
 DPDC("ss.input.port10.mouse", SSMouseConfig),
 DPDC("ss.input.port11.mouse", SSMouseConfig),
 DPDC("ss.input.port12.mouse", SSMouseConfig),

 DPDC("ss.input.port1.gun", SSGunConfig),
 DPDC("ss.input.port2.gun", SSGunConfig),
 DPDC("ss.input.port3.gun", SSGunConfig),
 DPDC("ss.input.port4.gun", SSGunConfig),
 DPDC("ss.input.port5.gun", SSGunConfig),
 DPDC("ss.input.port6.gun", SSGunConfig),
 DPDC("ss.input.port7.gun", SSGunConfig),
 DPDC("ss.input.port8.gun", SSGunConfig),
 DPDC("ss.input.port9.gun", SSGunConfig),
 DPDC("ss.input.port10.gun", SSGunConfig),
 DPDC("ss.input.port11.gun", SSGunConfig),
 DPDC("ss.input.port12.gun", SSGunConfig),

 DPDC("ss.input.port1.keyboard", SSKeyboardConfig),
 DPDC("ss.input.port2.keyboard", SSKeyboardConfig),
 DPDC("ss.input.port3.keyboard", SSKeyboardConfig),
 DPDC("ss.input.port4.keyboard", SSKeyboardConfig),
 DPDC("ss.input.port5.keyboard", SSKeyboardConfig),
 DPDC("ss.input.port6.keyboard", SSKeyboardConfig),
 DPDC("ss.input.port7.keyboard", SSKeyboardConfig),
 DPDC("ss.input.port8.keyboard", SSKeyboardConfig),
 DPDC("ss.input.port9.keyboard", SSKeyboardConfig),
 DPDC("ss.input.port10.keyboard", SSKeyboardConfig),
 DPDC("ss.input.port11.keyboard", SSKeyboardConfig),
 DPDC("ss.input.port12.keyboard", SSKeyboardConfig),

 DPDC("ss.input.port1.jpkeyboard", SSJPKeyboardConfig),
 DPDC("ss.input.port2.jpkeyboard", SSJPKeyboardConfig),
 DPDC("ss.input.port3.jpkeyboard", SSJPKeyboardConfig),
 DPDC("ss.input.port4.jpkeyboard", SSJPKeyboardConfig),
 DPDC("ss.input.port5.jpkeyboard", SSJPKeyboardConfig),
 DPDC("ss.input.port6.jpkeyboard", SSJPKeyboardConfig),
 DPDC("ss.input.port7.jpkeyboard", SSJPKeyboardConfig),
 DPDC("ss.input.port8.jpkeyboard", SSJPKeyboardConfig),
 DPDC("ss.input.port9.jpkeyboard", SSJPKeyboardConfig),
 DPDC("ss.input.port10.jpkeyboard", SSJPKeyboardConfig),
 DPDC("ss.input.port11.jpkeyboard", SSJPKeyboardConfig),
 DPDC("ss.input.port12.jpkeyboard", SSJPKeyboardConfig),

 DPDC("mmplay.input.builtin.controller", MMPlayInputConfig),
 DPDC("cdplay.input.builtin.controller", CDPlayInputConfig),
 #undef DPDC
};

