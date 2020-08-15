extern int32 fps_scale;

void ConfigSound();
int InitSound();
void TrashSound();
void TrashSoundNow();
void win_SoundSetScale(int scale);
void win_SoundWriteData(int32 *buffer, int count);
void win_Throttle();
extern bool muteTurbo;
extern int soundo;
