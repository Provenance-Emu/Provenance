#ifndef _MSC_VER
#include <stdbool.h>
#endif
#include <sched.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#ifndef __CELLOS_LV2__
//#include <malloc.h>
#endif

//#ifdef _MSC_VER
//#define snprintf _snprintf
//#pragma pack(1)
//#endif

#include "libretro.h"

#include "Settings.hxx"
#include "TIA.hxx"
#include "Props.hxx"
#include "PropsSet.hxx"
#include "Cart.hxx"
#include "Console.hxx"
#include "Serializer.hxx"
#include "Event.hxx"
#include "Switches.hxx"
#include "MD5.hxx"
#include "SoundSDL.hxx"
#include "Paddles.hxx"

struct					Stella
{
	Console*			GameConsole;
	Settings			GameSettings;
    
	const uInt32*		Palette;
    
	SoundSDL			Sound;
    
	Stella() 	{GameConsole = 0; Palette = 0;}
	~Stella()	{delete GameConsole;}
};
Stella*				stella;

static uint32_t frame_buffer[256*160];
uint8_t samplebuffer[2048];
//Set the palette for the current stella instance
void stellaMDFNSetPalette (const uInt32* palette) {
	if(stella) {
		stella->Palette = palette;
	}
}

//Get the settings from the current stella instance
Settings& stellaMDFNSettings () {
	if(stella) {
		return stella->GameSettings;
	}
    
	//HACK
	abort();
}

static retro_video_refresh_t video_cb;
static retro_input_poll_t input_poll_cb;
static retro_input_state_t input_state_cb;
static retro_environment_t environ_cb;
static retro_audio_sample_t audio_cb;
static retro_audio_sample_batch_t audio_batch_cb;

void stella_retro_set_environment(retro_environment_t cb) { environ_cb = cb; }
void stella_retro_set_video_refresh(retro_video_refresh_t cb) { video_cb = cb; }
void stella_retro_set_audio_sample(retro_audio_sample_t cb) { audio_cb = cb; }
void stella_retro_set_audio_sample_batch(retro_audio_sample_batch_t cb) { audio_batch_cb = cb; }
void stella_retro_set_input_poll(retro_input_poll_t cb) { input_poll_cb = cb; }
void stella_retro_set_input_state(retro_input_state_t cb) { input_state_cb = cb; }

static void stella_update_input() {

    if (!input_poll_cb) {
        return;
    }
    
    input_poll_cb();
    
    //Update stella's event structure
    stella->GameConsole->event().set(Event::JoystickZeroUp, input_state_cb(Controller::Left, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP));
    stella->GameConsole->event().set(Event::JoystickZeroDown, input_state_cb(Controller::Left, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN));
    stella->GameConsole->event().set(Event::JoystickZeroLeft, input_state_cb(Controller::Left, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT));
    stella->GameConsole->event().set(Event::JoystickZeroRight, input_state_cb(Controller::Left, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT));
    stella->GameConsole->event().set(Event::JoystickZeroFire1, input_state_cb(Controller::Left, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B));
    stella->GameConsole->event().set(Event::JoystickZeroFire2, input_state_cb(Controller::Left, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A));
    stella->GameConsole->event().set(Event::JoystickZeroFire3, input_state_cb(Controller::Left, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_X));
    
    stella->GameConsole->event().set(Event::ConsoleLeftDiffA, input_state_cb(Controller::Left, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L));
    stella->GameConsole->event().set(Event::ConsoleLeftDiffB, input_state_cb(Controller::Left, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L2));
    stella->GameConsole->event().set(Event::ConsoleColor, input_state_cb(Controller::Left, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L3));
    stella->GameConsole->event().set(Event::ConsoleRightDiffA, input_state_cb(Controller::Left, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R));
    stella->GameConsole->event().set(Event::ConsoleRightDiffB, input_state_cb(Controller::Left, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R2));
    stella->GameConsole->event().set(Event::ConsoleBlackWhite, input_state_cb(Controller::Left, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R3));
    
    stella->GameConsole->event().set(Event::ConsoleSelect, input_state_cb(Controller::Left, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT));
    stella->GameConsole->event().set(Event::ConsoleReset, input_state_cb(Controller::Left, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START));
    
    //Events for right player's joystick
    stella->GameConsole->event().set(Event::JoystickOneUp, input_state_cb(Controller::Right, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP));
    stella->GameConsole->event().set(Event::JoystickOneDown, input_state_cb(Controller::Right, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN));
    stella->GameConsole->event().set(Event::JoystickOneLeft, input_state_cb(Controller::Right, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT));
    stella->GameConsole->event().set(Event::JoystickOneRight, input_state_cb(Controller::Right, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT));
    stella->GameConsole->event().set(Event::JoystickOneFire1, input_state_cb(Controller::Right, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B));
    stella->GameConsole->event().set(Event::JoystickOneFire2, input_state_cb(Controller::Right, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A));
    stella->GameConsole->event().set(Event::JoystickOneFire3, input_state_cb(Controller::Right, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_X));
    
    //stella->GameConsole->fry();
    //Tell all input devices to read their state from the event structure
    stella->GameConsole->controller(Controller::Left).update();
    stella->GameConsole->controller(Controller::Right).update();
    stella->GameConsole->switches().update();
}

/************************************
 * libretro implementation
 ************************************/

static struct retro_system_av_info g_av_info;

void stella_retro_get_system_info(struct retro_system_info *info)
{
    memset(info, 0, sizeof(*info));
	info->library_name = "Stella";
	info->library_version = "3.4.1";
	info->need_fullpath = true;
	info->valid_extensions = "a26|A26";
}

void stella_retro_get_system_av_info(struct retro_system_av_info *info)
{
    memset(info, 0, sizeof(*info));
    // Just assume NTSC for now. TODO: Verify FPS.
    info->timing.fps            = stella->GameConsole->getFramerate();
    info->timing.sample_rate    = 31400;
    info->geometry.base_width   = 160;
    info->geometry.base_height  = 210;
    info->geometry.max_width    = 160;
    info->geometry.max_height   = 256;
    info->geometry.aspect_ratio = 4.0 / 3.0;
}

void stella_retro_set_controller_port_device(unsigned port, unsigned device)
{
   (void)port;
   (void)device;
}

size_t stella_retro_serialize_size(void)
{ 
	return 0xfc080;
	//return 0;
}

bool stella_retro_serialize(void *data, size_t size)
{ 
    //if (size != STATE_SIZE)
    //    return false;
    
    //Serializer state((uint8_t*)data);
    //Serializer(const string& filename, bool readonly = false);
    
    //Serializer state((const string&) data);
    //stella->GameConsole->save((Serializer&)state);
    
    Serializer state((StateMem *)data);
    stella->GameConsole->save(state);

    return false;
}

bool stella_retro_unserialize(const void *data, size_t size)
{
    //if (size != STATE_SIZE)
    //    return false;
    
    //Serializer state((uint8_t*)data);
    //stella->GameConsole->load(state);
    
    //Serializer state((const string&) data);
    //stella->GameConsole->load((Serializer&)state);
    
    Serializer state((StateMem *)data);
    stella->GameConsole->load(state);
    
    return true;
}

void stella_retro_cheat_reset(void)
{}

void stella_retro_cheat_set(unsigned index, bool enabled, const char *code)
{
   (void)index;
   (void)enabled;
   (void)code;
}

bool stella_retro_load_game(const struct retro_game_info *info)
{
    stella = new Stella();
    const char *full_path;
    
    full_path = info->path;
    
	//Get the game properties
    string cartMD5 = MD5((const uInt8*)info->data, info->size);
    PropertiesSet propslist(0);
    Properties gameProperties;
    propslist.getMD5(cartMD5, gameProperties);
    
    //Input - Set paddles for games that require them (Range: 1-10)
    Paddles::setDigitalSensitivity(5);
    Paddles::setMouseSensitivity(5);
    
    //Load the cart
    string cartType = gameProperties.get(Cartridge_Type);
    string cartID = "";
    Cartridge* stellaCart = Cartridge::create((const uInt8*)info->data, (uInt32)info->size, cartMD5, cartType, cartID, stella->GameSettings);
    
    //printf("%s %d\n", cartMD5.c_str(), info->size);
    if(stellaCart == 0)
    {
        printf("Stella: Failed to load cartridge.");
        return false;
    }
    
    //Create the console
    stella->GameConsole = new Console(stella->Sound, stellaCart, gameProperties);
    
    //Init sound
    stella->Sound.open();
    
    //stella->Palette = 0; //NTSC

   return true;
}

bool stella_retro_load_game_special(unsigned game_type, const struct stella_retro_game_info *info, size_t num_info)
{
   (void)game_type;
   (void)info;
   (void)num_info;
   return false;
}

void stella_retro_unload_game(void)
{

}

unsigned stella_retro_get_region(void)
{
    //stella->GameConsole->getFramerate();
    return RETRO_REGION_NTSC;
}

unsigned stella_retro_api_version(void)
{
    return RETRO_API_VERSION;
}

void *stella_retro_get_memory_data(unsigned id)
{
    return NULL;
}

size_t stella_retro_get_memory_size(unsigned id)
{
    return 0;
}

void stella_retro_init(void)
{
    unsigned level = 3;
    environ_cb(RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL, &level);
}

void stella_retro_deinit(void)
{
    delete stella;
    stella = 0;
	//free(frame_buffer);
}

void stella_retro_reset(void)
{
	stella->GameConsole->system().reset();
}

void stella_retro_run(void)
{
    //INPUT
    stella_update_input();
    
    //EMULATE
    stella->GameConsole->tia().update();
    
    //VIDEO
    //Get the frame info from stella
    Int32 frameWidth = stella->GameConsole->tia().width();
    Int32 frameHeight = stella->GameConsole->tia().height();
    
    //Copy the frame from stella to video buffer
    for ( unsigned int i = 0; i < frameHeight * frameWidth; ++i )
        frame_buffer[i] = stella->Palette[stella->GameConsole->tia().currentFrameBuffer()[i]];
    
    video_cb(frame_buffer, frameWidth, frameHeight, frameWidth << 2);

    //AUDIO
    //Get the number of samples in a frame
    uint32_t soundFrameSize = 31400.0f / stella->GameConsole->getFramerate();
    
    //Process one frame of audio from stella

    //const int16_t * final_samplebuffer;
    stella->Sound.processFragment(samplebuffer, soundFrameSize);
    
    int16_t sample;
    //Convert and stash it in the resampler...
    for(int i = 0; i != soundFrameSize; i ++)
    {
        sample = (samplebuffer[i] << 8) - 32768;
        int16_t frame[2] = {sample, sample};
        //Resampler::Fill(frame, 2);
        audio_cb(frame[0], frame[1]);
        //audio_batch_cb((const int16_t *)sample, soundFrameSize);
        //memcpy(&final_samplebuffer, &sample, 2 * 2);
    }
    
    //TODO: fix
    //The array you pass in batch callback has to be interleaved signed 16-bit stereo
    //audio_batch_cb((const int16_t *)samplebuffer, soundFrameSize);
    //audio_batch_cb((const int16_t *)sample, soundFrameSize);
    //audio_batch_cb(final_samplebuffer, soundFrameSize);
    
    /* convert uint16_t to uint8_t */
    //uint16_t A = 120;
    //uint8_t B;
    
    //B = (uint8_t)A; // Get lower byte of 16-bit var
    //B = (uint8_t)(A >> 8); // Get upper byte of 16-bit var
    
    /* convert 2 uint8_t to uint16_t */
    //uint8_t d1=0x01;
    //uint8_t d2=0x02;
    
    //uint16_t wd;
    
    //union {
    //    uint8_t bytes[2];
    //    int n;
    //} join;
    //join.bytes[0] = d1;
    //join.bytes[1] = d2;
    //wd = join.n;
    //while(1) {
    //}
}
