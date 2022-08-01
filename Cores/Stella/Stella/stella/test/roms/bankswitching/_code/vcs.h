;
; VCS system equates
;
; Vertical blank registers
;
VSYNC   =  $00
VS_Enable = 2
;
VBLANK  =  $01
VB_Enable      = 2
VB_Disable     = 0
VB_LatchEnable = 64
VB_LatchDisable = 0
VB_DumpPots    = 128
; I don't know a good name to un-dump the pots,
; at least that makes sense.

WSYNC   =  $02
RSYNC   =  $03   ;for sadists
;
; Size registers for players and missiles
;
NUSIZ0  =  $04
NUSIZ1  =  $05
P_Single      = 0
P_TwoClose    = 1
P_TwoMedium   = 2
P_ThreeClose  = 3
P_TwoFar      = 4
P_Double      = 5
P_ThreeMedium = 6
P_Quad        = 7

M_Single      = $00
M_Double      = $10
M_Quad        = $20
M_Oct         = $40

;
; Color registers
;
COLUP0  =  $06
COLUP1  =  $07
COLUPF  =  $08
COLUBK  =  $09

;
; Playfield Control
;
CTRLPF  =  $0A
PF_Reflect  = $01
PF_Score    = $02 
PF_Priority = $04
; Use missile equates to set ball width.

REFP0   =  $0B
REFP1   =  $0C
P_Reflect = $08

PF0     =  $0D
PF1     =  $0E
PF2     =  $0F
RESP0   =  $10
RESP1   =  $11
RESM0   =  $12
RESM1   =  $13
RESBL   =  $14
AUDC0   =  $15
AUDC1   =  $16
AUDF0   =  $17
AUDF1   =  $18
AUDV0   =  $19
AUDV1   =  $1A  ;duh

;
; Players
;
GRP0    =  $1B
GRP1    =  $1C

;
; Single-bit objects
;
ENAM0   =  $1D
ENAM1   =  $1E
ENABL   =  $1F
M_Enable = 2

HMP0    =  $20
HMP1    =  $21
HMM0    =  $22
HMM1    =  $23
HMBL    =  $24

; Miscellaneous
VDELP0  =  $25
VDEL01  =  $26
VDELP1  =  $26
VDELBL  =  $27
RESMP0  =  $28
RESMP1  =  $29
HMOVE   =  $2A
HMCLR   =  $2B
CXCLR   =  $2C
CXM0P   =  $30
CXM1P   =  $31
CXP0FB  =  $32
CXP1FB  =  $33
CXM0FB  =  $34
CXM1FB  =  $35
CXBLPF  =  $36
CXPPMM  =  $37
INPT0   =  $38
INPT1   =  $39
INPT2   =  $3A
INPT3   =  $3B
INPT4   =  $3C
INPT5   =  $3D

;
; Switch A equates.
;
; There are more elegant ways than using all eight of these.  :-)
;
SWCHA   =  $0280
J0_Right = $80
J0_Left  = $40
J0_Down  = $20
J0_Up    = $10
J1_Right = $08
J1_Left  = $04
J1_Down  = $02
J1_up    = $01
;
; Switch B equates
;
SWCHB   =  $0282
P0_Diff = $80
P1_Diff = $40
Con_Color  = $08
Con_Select = $02
Con_Start  = $01

;
; Timer
;
SWCHA   =  $0280
SWACNT  =  $0281
SWCHB   =  $0282
SWBCNT  =  $0283
INTIM   =  $0284
TIM1T   =  $0294
TIM8T   =  $0295
TIM64T  =  $0296
TIM1024T = $0297


