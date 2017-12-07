music_pmintro:
	PMMUSIC_PATTERN music_pmintroPatt

music_pmintroPatt:

	PMMUSIC_ROW	N_E_5, $80, 3, 4
	PMMUSIC_ROW	N_E_5, $80, 2, 4
	PMMUSIC_ROW	N_A_5, $80, 3, 4
	PMMUSIC_ROW	N_A_5, $80, 2, 4
	PMMUSIC_ROW	N____,  -1, 0, 9
	PMMUSIC_ROW	N_D_6, $80, 3, 4
	PMMUSIC_ROW	N_D_6, $80, 2, 4
	PMMUSIC_ROW	N_CS6, $80, 3, 4
	PMMUSIC_ROW	N_CS6, $80, 2, 4
	PMMUSIC_ROW	N_A_5, $80, 3, 4
	PMMUSIC_ROW	N_A_5, $80, 2, 4
	PMMUSIC_ROW	N_E_6, $80, 3, 4
	PMMUSIC_ROW	N_E_6, $80, 2, 4
	PMMUSIC_ROW	N____,  -1, 0, 24
	PMMUSIC_ROW	N_D_6, $80, 3, 3
	PMMUSIC_ROW	N_A_6, $80, 3, 3
	PMMUSIC_ROW	N_E_7, $80, 3, 3
	PMMUSIC_ROW	N_B_7, $80, 3, 3
	PMMUSIC_ROW	N_E_7, $80, 3, 3
	PMMUSIC_ROW	N_B_7, $80, 3, 3
	PMMUSIC_ROW	N____,  -1, 0, 6

	PMMUSIC_END

music_pmintro_end:
	.printf "Music PMIntro size: %i bytes\n", music_pmintro_end - music_pmintro
