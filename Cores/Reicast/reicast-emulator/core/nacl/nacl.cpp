#include <cstdio>
#include <cstdarg>
#include <cstring>
#include <string>
#include "ppapi/cpp/instance.h"
#include "ppapi/cpp/module.h"
#include "ppapi/cpp/var.h"

#include <sys/mount.h>
#include "nacl_io/ioctl.h"
#include "nacl_io/nacl_io.h"

#include "ppapi/cpp/graphics_3d.h"
#include "ppapi/lib/gl/gles2/gl2ext_ppapi.h"
#include "ppapi/utility/completion_callback_factory.h"

#include "types.h"
#include "maple_cfg.h"

#include <GLES2/gl2.h>

extern int screen_width,screen_height;
bool rend_single_frame();
bool gles_init();
extern "C" int reicast_main(int argc, char* argv[]);

int msgboxf(const wchar* text,unsigned int type,...)
{
	va_list args;

	wchar temp[2048];
	va_start(args, type);
	vsprintf(temp, text, args);
	va_end(args);

	puts(temp);
	return 0;
}

int dc_init(int argc,wchar* argv[]);
void dc_run();

bool rend_framePending();

pthread_t emut;

void* emuthread(void* ) {
  printf("Emu thread starting up");
  char *Args[3];
  Args[0] = "dc";

	set_user_config_dir("/http");
	set_user_data_dir("/http");

  dc_init(1,Args);
  dc_run();

  return 0;
}

namespace hello_world
{
  class HelloWorldInstance;
  HelloWorldInstance* rei_instance;
class HelloWorldInstance : public pp::Instance {
 public:
  explicit HelloWorldInstance(PP_Instance instance) : pp::Instance(instance), callback_factory_(this) {
    rei_instance = this;
    printf("Reicast NACL loaded\n");
    nacl_io_init_ppapi(instance, pp::Module::Get()->get_browser_interface());

    umount("/");
    mount("", "/", "memfs", 0, "");

    mount("",       /* source. Use relative URL */
          "/http",  /* target */
          "httpfs", /* filesystemtype */
          0,        /* mountflags */
          "");      /* data */


    pthread_create(&emut, NULL, emuthread, 0);
  }
  virtual ~HelloWorldInstance() {}

  pp::CompletionCallbackFactory<HelloWorldInstance> callback_factory_;
  pp::Graphics3D context_;
  int32_t width_;
  int32_t height_;

  /// Called by the browser to handle the postMessage() call in Javascript.
  /// Detects which method is being called from the message contents, and
  /// calls the appropriate function.  Posts the result back to the browser
  /// asynchronously.
  /// @param[in] var_message The message posted by the browser.  The possible
  ///     messages are 'fortyTwo' and 'reverseText:Hello World'.  Note that
  ///     the 'reverseText' form contains the string to reverse following a ':'
  ///     separator.
  virtual void HandleMessage(const pp::Var& var_message);

  bool InitGL(int32_t new_width, int32_t new_height) {
    if (!glInitializePPAPI(pp::Module::Get()->get_browser_interface())) {
      fprintf(stderr, "Unable to initialize GL PPAPI!\n");
      return false;
    }

    const int32_t attrib_list[] = {
      PP_GRAPHICS3DATTRIB_ALPHA_SIZE, 8,
      PP_GRAPHICS3DATTRIB_DEPTH_SIZE, 24,
      PP_GRAPHICS3DATTRIB_WIDTH, new_width,
      PP_GRAPHICS3DATTRIB_HEIGHT, new_height,
      PP_GRAPHICS3DATTRIB_NONE
    };

    context_ = pp::Graphics3D(this, attrib_list);
    if (!BindGraphics(context_)) {
      fprintf(stderr, "Unable to bind 3d context!\n");
      context_ = pp::Graphics3D();
      glSetCurrentContextPPAPI(0);
      return false;
    }

    glSetCurrentContextPPAPI(context_.pp_resource());
    return true;
  }

  virtual void DidChangeView(const pp::View& view) {
    // Pepper specifies dimensions in DIPs (device-independent pixels). To
    // generate a context that is at device-pixel resolution on HiDPI devices,
    // scale the dimensions by view.GetDeviceScale().
    int32_t new_width = view.GetRect().width() * view.GetDeviceScale();
    int32_t new_height = view.GetRect().height() * view.GetDeviceScale();

    if (context_.is_null()) {
      if (!InitGL(new_width, new_height)) {
        // failed.
        return;
      }

      verify(gles_init() == true);
      RenderLoop(0);
    } else {
      // Resize the buffers to the new size of the module.
      int32_t result = context_.ResizeBuffers(new_width, new_height);
      if (result < 0) {
        printf("Unable to resize buffers to %d x %d!\n");
        return;
      }
    }

    width_ = new_width;
    height_ = new_height;
    glViewport(0, 0, width_, height_);
    printf("Resize: %d x %d\n", new_width, new_height);
  }


  void RenderLoop(int32_t) {

    screen_width = width_;
    screen_height = height_;

    glClearColor(0.65f, 0.65f, 0.65f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    if (rend_framePending()) {
      while (!rend_single_frame()) ;
      printf("Rendered frame\n");
    }

    printf("Swapping buffers\n");
    context_.SwapBuffers(
        callback_factory_.NewCallback(&HelloWorldInstance::RenderLoop));
  }

};

void HelloWorldInstance::HandleMessage(const pp::Var& var_message) {
  if (!var_message.is_string()) {
    return;
  }

  // Post the return result back to the browser.  Note that HandleMessage() is
  // always called on the main thread, so it's OK to post the return message
  // directly from here.  The return post is asynhronous: PostMessage returns
  // immediately.

  //PostMessage(return_var);
}

/// The Module class.  The browser calls the CreateInstance() method to create
/// an instance of your NaCl module on the web page.  The browser creates a new
/// instance for each <embed> tag with
/// <code>type="application/x-nacl"</code>.
class HelloWorldModule : public pp::Module {
 public:
  HelloWorldModule() : pp::Module() {

  }
  virtual ~HelloWorldModule() {}

  /// Create and return a HelloWorldInstance object.
  /// @param[in] instance a handle to a plug-in instance.
  /// @return a newly created HelloWorldInstance.
  /// @note The browser is responsible for calling @a delete when done.
  virtual pp::Instance* CreateInstance(PP_Instance instance) {
    return new HelloWorldInstance(instance);
  }
};
}  // namespace hello_world

int nacl_printf(const wchar* text,...)
{
  va_list args;

  wchar temp[2048];
  va_start(args, text);
  int rv = vsprintf(temp, text, args);
  va_end(args);

  if (hello_world::rei_instance)
    hello_world::rei_instance->PostMessage(pp::Var(temp));
  return rv;
}

namespace pp {
/// Factory function called by the browser when the module is first loaded.
/// The browser keeps a singleton of this module.  It calls the
/// CreateInstance() method on the object you return to make instances.  There
/// is one instance per <embed> tag on the page.  This is the main binding
/// point for your NaCl module with the browser.
/// @return new HelloWorldModule.
/// @note The browser is responsible for deleting returned @a Module.
Module* CreateModule() {
  return new hello_world::HelloWorldModule();
}
}  // namespace pp


u16 kcode[4];
u32 vks[4];
s8 joyx[4],joyy[4];
u8 rt[4],lt[4];

int get_mic_data(u8* buffer) { return 0; }
int push_vmu_screen(u8* buffer) { return 0; }

void os_SetWindowText(const char * text) {
  puts(text);
}

void os_DoEvents() {

}

void os_SetupInput() {
	mcfg_CreateDevicesFromConfig();
}

void UpdateInputState(u32 port) {

}

void UpdateVibration(u32 port, u32 value) {

}

void os_CreateWindow() {

}

void os_DebugBreak() {
    exit(1);
}

void* libPvr_GetRenderTarget() {
    return 0;
}

void* libPvr_GetRenderSurface() {
    return 0;

}

bool gl_init(void*, void*) {
    return true;
}

void gl_term() {

}

void gl_swap() {

}
