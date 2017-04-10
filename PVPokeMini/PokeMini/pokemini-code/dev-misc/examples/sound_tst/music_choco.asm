music_choco:
	PMMUSIC_PATTERN music_chocoP1
	PMMUSIC_PATTERN music_chocoP2
	PMMUSIC_PATTERN music_chocoP2
	PMMUSIC_PATTERN music_chocoP3
	PMMUSIC_PATTERN music_chocoP4
	PMMUSIC_PATTERN music_chocoP5
	PMMUSIC_PATTERN music_chocoEnd
music_chocoEnd:
	PMMUSIC_GOBACK 6

.equ	cI0	$60
.equ	cI1	$30

music_chocoP1:
	PMMUSIC_ROW N_G_5, cI0, 3, 6	; 00
	PMMUSIC_ROW N____,  -1, 2, 6	; 01
	PMMUSIC_ROW N____,  -1, 0, 6	; 02
	PMMUSIC_ROW N____,  -1, 0, 6	; 03
	PMMUSIC_ROW N_D_6, cI0, 3, 6	; 04
	PMMUSIC_ROW N____,  -1, 2, 6	; 05
	PMMUSIC_ROW N_G_5, cI0, 3, 6	; 06
	PMMUSIC_ROW N____,  -1, 2, 6	; 07
	PMMUSIC_ROW N_F_5, cI0, 3, 6	; 08
	PMMUSIC_ROW N____,  -1, 2, 6	; 09
	PMMUSIC_ROW N_C_6, cI0, 3, 6	; 0A
	PMMUSIC_ROW N____,  -1, 2, 6	; 0B
	PMMUSIC_ROW N____,  -1, 0, 6	; 0C
	PMMUSIC_ROW N____,  -1, 0, 6	; 0D
	PMMUSIC_ROW N_C_6, cI0, 3, 6	; 0E
	PMMUSIC_ROW N____,  -1, 2, 6	; 0F
	PMMUSIC_ROW N_G_5, cI0, 3, 6	; 10
	PMMUSIC_ROW N____,  -1, 2, 6	; 11
	PMMUSIC_ROW N_D_6, cI0, 3, 6	; 12
	PMMUSIC_ROW N____,  -1, 2, 6	; 13
	PMMUSIC_ROW N_G_5, cI0, 3, 6	; 14
	PMMUSIC_ROW N____,  -1, 2, 6	; 15
	PMMUSIC_ROW N_D_6, cI0, 3, 6	; 16
	PMMUSIC_ROW N____,  -1, 2, 6	; 17
	PMMUSIC_ROW N_F_5, cI0, 3, 6	; 18
	PMMUSIC_ROW N____,  -1, 2, 6	; 19
	PMMUSIC_ROW N____,  -1, 0, 6	; 1A
	PMMUSIC_ROW N____,  -1, 0, 6	; 1B
	PMMUSIC_ROW N_C_6, cI0, 3, 6	; 1C
	PMMUSIC_ROW N____,  -1, 2, 6	; 1D
	PMMUSIC_ROW N_F_5, cI0, 3, 6	; 1E
	PMMUSIC_ROW N____,  -1, 2, 6	; 1F
	PMMUSIC_ROW N_G_5, cI0, 3, 6	; 20
	PMMUSIC_ROW N____,  -1, 2, 6	; 21
	PMMUSIC_ROW N____,  -1, 0, 6	; 22
	PMMUSIC_ROW N____,  -1, 0, 6	; 23
	PMMUSIC_ROW N_D_6, cI0, 3, 6	; 24
	PMMUSIC_ROW N____,  -1, 2, 6	; 25
	PMMUSIC_ROW N_G_5, cI0, 3, 6	; 26
	PMMUSIC_ROW N____,  -1, 2, 6	; 27
	PMMUSIC_ROW N_F_5, cI0, 3, 6	; 28
	PMMUSIC_ROW N____,  -1, 2, 6	; 29
	PMMUSIC_ROW N_C_6, cI0, 3, 6	; 2A
	PMMUSIC_ROW N____,  -1, 2, 6	; 2B
	PMMUSIC_ROW N____,  -1, 0, 6	; 2C
	PMMUSIC_ROW N____,  -1, 0, 6	; 2D
	PMMUSIC_ROW N_C_6, cI0, 3, 6	; 2E
	PMMUSIC_ROW N____,  -1, 2, 6	; 2F
	PMMUSIC_ROW N_G_5, cI0, 3, 6	; 30
	PMMUSIC_ROW N____,  -1, 2, 6	; 31
	PMMUSIC_ROW N_D_6, cI0, 3, 6	; 32
	PMMUSIC_ROW N____,  -1, 2, 6	; 33
	PMMUSIC_ROW N_G_5, cI0, 3, 6	; 34
	PMMUSIC_ROW N____,  -1, 2, 6	; 35
	PMMUSIC_ROW N_D_6, cI0, 3, 6	; 36
	PMMUSIC_ROW N____,  -1, 2, 6	; 37
	PMMUSIC_ROW N_F_5, cI0, 3, 6	; 38
	PMMUSIC_ROW N____,  -1, 2, 6	; 39
	PMMUSIC_ROW N____,  -1, 0, 6	; 3A
	PMMUSIC_ROW N____,  -1, 0, 6	; 3B
	PMMUSIC_ROW N_C_6, cI0, 3, 6	; 3C
	PMMUSIC_ROW N____,  -1, 2, 6	; 3D
	PMMUSIC_ROW N_F_5, cI0, 3, 6	; 3E
	PMMUSIC_ROW N____,  -1, 2, 6	; 3F
	PMMUSIC_NEXT

music_chocoP2:
	PMMUSIC_ROW N_D_7, cI1, 3, 6	; 00
	PMMUSIC_ROW N____,  -1, 3, 6	; 01
	PMMUSIC_ROW N____,  -1, 2, 6	; 02
	PMMUSIC_ROW N____,  -1, 2, 6	; 03
	PMMUSIC_ROW N_B_6, cI1, 3, 6	; 04
	PMMUSIC_ROW N____,  -1, 2, 6	; 05
	PMMUSIC_ROW N_G_6, cI1, 3, 6	; 06
	PMMUSIC_ROW N____,  -1, 2, 6	; 07
	PMMUSIC_ROW N_E_6, cI1, 3, 6	; 08
	PMMUSIC_ROW N____,  -1, 2, 6	; 09
	PMMUSIC_ROW N_D_7, cI1, 3, 6	; 0A
	PMMUSIC_ROW N____,  -1, 2, 6	; 0B
	PMMUSIC_ROW N_B_6, cI1, 3, 6	; 0C
	PMMUSIC_ROW N____,  -1, 2, 6	; 0D
	PMMUSIC_ROW N_G_6, cI1, 3, 6	; 0E
	PMMUSIC_ROW N____,  -1, 2, 6	; 0F
	PMMUSIC_ROW N_B_6, cI1, 3, 6	; 10
	PMMUSIC_ROW N____,  -1, 3, 6	; 11
	PMMUSIC_ROW N____,  -1, 2, 6	; 12
	PMMUSIC_ROW N____,  -1, 2, 6	; 13
	PMMUSIC_ROW N_G_6, cI1, 3, 6	; 14
	PMMUSIC_ROW N____,  -1, 3, 6	; 15
	PMMUSIC_ROW N____,  -1, 2, 6	; 16
	PMMUSIC_ROW N____,  -1, 2, 6	; 17
	PMMUSIC_ROW N_B_6, cI1, 3, 6	; 18
	PMMUSIC_ROW N____,  -1, 3, 6	; 19
	PMMUSIC_ROW N____,  -1, 3, 6	; 1A
	PMMUSIC_ROW N____,  -1, 2, 6	; 1B
	PMMUSIC_ROW N____,  -1, 2, 6	; 1C
	PMMUSIC_ROW N____,  -1, 2, 6	; 1D
	PMMUSIC_ROW N_A_6, cI1, 3, 6	; 1E
	PMMUSIC_ROW N____,  -1, 2, 6	; 1F
	PMMUSIC_ROW N_G_6, cI1, 3, 6	; 20
	PMMUSIC_ROW N____,  -1, 2, 6	; 21
	PMMUSIC_ROW N_G_6, cI1, 3, 6	; 22
	PMMUSIC_ROW N_A_6, cI1, 3, 6	; 23
	PMMUSIC_ROW N_G_6, cI1, 3, 6	; 24
	PMMUSIC_ROW N____,  -1, 2, 6	; 25
	PMMUSIC_ROW N_F_6, cI1, 3, 6	; 26
	PMMUSIC_ROW N____,  -1, 2, 6	; 27
	PMMUSIC_ROW N_G_6, cI1, 3, 6	; 28
	PMMUSIC_ROW N____,  -1, 3, 6	; 29
	PMMUSIC_ROW N____,  -1, 3, 6	; 2A
	PMMUSIC_ROW N____,  -1, 2, 6	; 2B
	PMMUSIC_ROW N____,  -1, 2, 6	; 2C
	PMMUSIC_ROW N____,  -1, 2, 6	; 2D
	PMMUSIC_ROW N_F_6, cI1, 3, 6	; 2E
	PMMUSIC_ROW N____,  -1, 2, 6	; 2F
	PMMUSIC_ROW N_G_6, cI1, 3, 6	; 30
	PMMUSIC_ROW N____,  -1, 2, 6	; 31
	PMMUSIC_ROW N_G_6, cI1, 3, 6	; 32
	PMMUSIC_ROW N_B_6, cI1, 3, 6	; 33
	PMMUSIC_ROW N_D_7, cI1, 3, 6	; 34
	PMMUSIC_ROW N____,  -1, 2, 6	; 35
	PMMUSIC_ROW N_E_7, cI1, 3, 6	; 36
	PMMUSIC_ROW N____,  -1, 2, 6	; 37
	PMMUSIC_ROW N_F_7, cI1, 3, 6	; 38
	PMMUSIC_ROW N____,  -1, 3, 6	; 39
	PMMUSIC_ROW N____,  -1, 3, 6	; 3A
	PMMUSIC_ROW N____,  -1, 2, 6	; 3B
	PMMUSIC_ROW N____,  -1, 2, 6	; 3C
	PMMUSIC_ROW N____,  -1, 2, 6	; 3D
	PMMUSIC_ROW N____,  -1, 1, 6	; 3E
	PMMUSIC_ROW N____,  -1, 1, 6	; 3F
	PMMUSIC_NEXT

music_chocoP3:
	PMMUSIC_ROW N_E_7, cI1, 3, 6	; 00
	PMMUSIC_ROW N____,  -1, 3, 6	; 01
	PMMUSIC_ROW N____,  -1, 2, 6	; 02
	PMMUSIC_ROW N____,  -1, 2, 6	; 03
	PMMUSIC_ROW N_C_7, cI1, 3, 6	; 04
	PMMUSIC_ROW N____,  -1, 2, 6	; 05
	PMMUSIC_ROW N_A_6, cI1, 3, 6	; 06
	PMMUSIC_ROW N____,  -1, 2, 6	; 07
	PMMUSIC_ROW N_FS6, cI1, 3, 6	; 08
	PMMUSIC_ROW N____,  -1, 2, 6	; 09
	PMMUSIC_ROW N_A_6, cI1, 3, 6	; 0A
	PMMUSIC_ROW N____,  -1, 2, 6	; 0B
	PMMUSIC_ROW N_C_7, cI1, 3, 6	; 0C
	PMMUSIC_ROW N____,  -1, 2, 6	; 0D
	PMMUSIC_ROW N_E_7, cI1, 3, 6	; 0E
	PMMUSIC_ROW N____,  -1, 2, 6	; 0F
	PMMUSIC_ROW N_D_7, cI1, 3, 6	; 10
	PMMUSIC_ROW N____,  -1, 3, 6	; 11
	PMMUSIC_ROW N____,  -1, 2, 6	; 12
	PMMUSIC_ROW N____,  -1, 2, 6	; 13
	PMMUSIC_ROW N_G_7, cI1, 3, 6	; 14
	PMMUSIC_ROW N____,  -1, 3, 6	; 15
	PMMUSIC_ROW N____,  -1, 2, 6	; 16
	PMMUSIC_ROW N____,  -1, 2, 6	; 17
	PMMUSIC_ROW N_D_7, cI1, 3, 6	; 18
	PMMUSIC_ROW N____,  -1, 3, 6	; 19
	PMMUSIC_ROW N____,  -1, 3, 6	; 1A
	PMMUSIC_ROW N____,  -1, 2, 6	; 1B
	PMMUSIC_ROW N____,  -1, 2, 6	; 1C
	PMMUSIC_ROW N____,  -1, 2, 6	; 1D
	PMMUSIC_ROW N_B_6, cI1, 3, 6	; 1E
	PMMUSIC_ROW N____,  -1, 2, 6	; 1F
	PMMUSIC_ROW N_C_7, cI1, 3, 6	; 20
	PMMUSIC_ROW N____,  -1, 3, 6	; 21
	PMMUSIC_ROW N____,  -1, 2, 6	; 22
	PMMUSIC_ROW N____,  -1, 2, 6	; 23
	PMMUSIC_ROW N_A_6, cI1, 3, 6	; 24
	PMMUSIC_ROW N____,  -1, 2, 6	; 25
	PMMUSIC_ROW N_FS6, cI1, 3, 6	; 26
	PMMUSIC_ROW N____,  -1, 2, 6	; 27
	PMMUSIC_ROW N_D_6, cI1, 3, 6	; 28
	PMMUSIC_ROW N____,  -1, 2, 6	; 29
	PMMUSIC_ROW N_FS6, cI1, 3, 6	; 2A
	PMMUSIC_ROW N____,  -1, 2, 6	; 2B
	PMMUSIC_ROW N_A_6, cI1, 3, 6	; 2C
	PMMUSIC_ROW N____,  -1, 2, 6	; 2D
	PMMUSIC_ROW N_C_7, cI1, 3, 6	; 2E
	PMMUSIC_ROW N____,  -1, 2, 6	; 2F
	PMMUSIC_ROW N_B_6, cI1, 3, 6	; 30
	PMMUSIC_ROW N____,  -1, 2, 6	; 31
	PMMUSIC_ROW N_B_6, cI1, 3, 6	; 32
	PMMUSIC_ROW N_C_7, cI1, 3, 6	; 33
	PMMUSIC_ROW N_B_6, cI1, 3, 6	; 34
	PMMUSIC_ROW N____,  -1, 2, 6	; 35
	PMMUSIC_ROW N_A_6, cI1, 3, 6	; 36
	PMMUSIC_ROW N____,  -1, 2, 6	; 37
	PMMUSIC_ROW N_B_6, cI1, 3, 6	; 38
	PMMUSIC_ROW N____,  -1, 3, 6	; 39
	PMMUSIC_ROW N____,  -1, 3, 6	; 3A
	PMMUSIC_ROW N____,  -1, 2, 6	; 3B
	PMMUSIC_ROW N____,  -1, 2, 6	; 3C
	PMMUSIC_ROW N____,  -1, 2, 6	; 3D
	PMMUSIC_ROW N____,  -1, 1, 6	; 3E
	PMMUSIC_ROW N____,  -1, 1, 6	; 3F
	PMMUSIC_NEXT

music_chocoP4:
	PMMUSIC_ROW N_E_7, cI1, 3, 6	; 00
	PMMUSIC_ROW N____,  -1, 3, 6	; 01
	PMMUSIC_ROW N____,  -1, 2, 6	; 02
	PMMUSIC_ROW N____,  -1, 2, 6	; 03
	PMMUSIC_ROW N_C_7, cI1, 3, 6	; 04
	PMMUSIC_ROW N____,  -1, 2, 6	; 05
	PMMUSIC_ROW N_A_6, cI1, 3, 6	; 06
	PMMUSIC_ROW N____,  -1, 2, 6	; 07
	PMMUSIC_ROW N_FS6, cI1, 3, 6	; 08
	PMMUSIC_ROW N____,  -1, 2, 6	; 09
	PMMUSIC_ROW N_A_6, cI1, 3, 6	; 0A
	PMMUSIC_ROW N____,  -1, 2, 6	; 0B
	PMMUSIC_ROW N_C_7, cI1, 3, 6	; 0C
	PMMUSIC_ROW N____,  -1, 2, 6	; 0D
	PMMUSIC_ROW N_E_7, cI1, 3, 6	; 0E
	PMMUSIC_ROW N____,  -1, 2, 6	; 0F
	PMMUSIC_ROW N_D_7, cI1, 3, 6	; 10
	PMMUSIC_ROW N____,  -1, 3, 6	; 11
	PMMUSIC_ROW N____,  -1, 2, 6	; 12
	PMMUSIC_ROW N____,  -1, 2, 6	; 13
	PMMUSIC_ROW N_G_7, cI1, 3, 6	; 14
	PMMUSIC_ROW N____,  -1, 3, 6	; 15
	PMMUSIC_ROW N____,  -1, 2, 6	; 16
	PMMUSIC_ROW N____,  -1, 2, 6	; 17
	PMMUSIC_ROW N_D_7, cI1, 3, 6	; 18
	PMMUSIC_ROW N____,  -1, 3, 6	; 19
	PMMUSIC_ROW N____,  -1, 3, 6	; 1A
	PMMUSIC_ROW N____,  -1, 2, 6	; 1B
	PMMUSIC_ROW N____,  -1, 2, 6	; 1C
	PMMUSIC_ROW N____,  -1, 2, 6	; 1D
	PMMUSIC_ROW N_B_6, cI1, 3, 6	; 1E
	PMMUSIC_ROW N____,  -1, 2, 6	; 1F
	PMMUSIC_ROW N_A_6, cI1, 3, 6	; 20
	PMMUSIC_ROW N____,  -1, 3, 6	; 21
	PMMUSIC_ROW N_A_6,  -1, 2, 6	; 22
	PMMUSIC_ROW N_B_6,  -1, 2, 6	; 23
	PMMUSIC_ROW N_A_6, cI1, 3, 6	; 24
	PMMUSIC_ROW N____,  -1, 2, 6	; 25
	PMMUSIC_ROW N_G_6, cI1, 3, 6	; 26
	PMMUSIC_ROW N____,  -1, 2, 6	; 27
	PMMUSIC_ROW N_A_6, cI1, 3, 6	; 28
	PMMUSIC_ROW N____,  -1, 3, 6	; 29
	PMMUSIC_ROW N____,  -1, 3, 6	; 2A
	PMMUSIC_ROW N____,  -1, 2, 6	; 2B
	PMMUSIC_ROW N____,  -1, 2, 6	; 2C
	PMMUSIC_ROW N____,  -1, 2, 6	; 2D
	PMMUSIC_ROW N_G_6, cI1, 3, 6	; 2E
	PMMUSIC_ROW N____,  -1, 2, 6	; 2F
	PMMUSIC_ROW N_A_6, cI1, 3, 6	; 30
	PMMUSIC_ROW N____,  -1, 2, 6	; 31
	PMMUSIC_ROW N_A_6, cI1, 3, 6	; 32
	PMMUSIC_ROW N_B_6, cI1, 3, 6	; 33
	PMMUSIC_ROW N_C_7, cI1, 3, 6	; 34
	PMMUSIC_ROW N____,  -1, 2, 6	; 35
	PMMUSIC_ROW N_D_7, cI1, 3, 6	; 36
	PMMUSIC_ROW N____,  -1, 2, 6	; 37
	PMMUSIC_ROW N_E_7, cI1, 3, 6	; 38
	PMMUSIC_ROW N____,  -1, 3, 6	; 39
	PMMUSIC_ROW N____,  -1, 2, 6	; 3A
	PMMUSIC_ROW N____,  -1, 2, 6	; 3B
	PMMUSIC_ROW N_FS7, cI1, 3, 6	; 3C
	PMMUSIC_ROW N____,  -1, 3, 6	; 3D
	PMMUSIC_ROW N____,  -1, 2, 6	; 3E
	PMMUSIC_ROW N____,  -1, 2, 6	; 3F
	PMMUSIC_NEXT

music_chocoP5:
	PMMUSIC_ROW N_G_7, cI1, 3, 6	; 00
	PMMUSIC_ROW N____,  -1, 3, 6	; 01
	PMMUSIC_ROW N____,  -1, 3, 6	; 02
	PMMUSIC_ROW N____,  -1, 2, 6	; 03
	PMMUSIC_ROW N____,  -1, 2, 6	; 02
	PMMUSIC_ROW N____,  -1, 2, 6	; 03
	PMMUSIC_ROW N____,  -1, 1, 6	; 02
	PMMUSIC_ROW N____,  -1, 1, 6	; 03
	PMMUSIC_ROW N____,  -1, 0, 48	; 03
	PMMUSIC_NEXT

music_choco_end:
	.printf "Music Chocobo size: %i bytes\n", music_choco_end - music_choco
