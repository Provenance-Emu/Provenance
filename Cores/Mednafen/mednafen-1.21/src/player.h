#ifndef __MDFN_PLAYER_H
#define __MDFN_PLAYER_H

void Player_Init(int tsongs, const std::string &album, const std::string &artist, const std::string &copyright, const std::vector<std::string> &snames = std::vector<std::string>(), bool override_gi = true) MDFN_COLD;
void Player_Draw(MDFN_Surface *surface, MDFN_Rect *dr, int CurrentSong, int16 *samples, int32 sampcount);

#endif
