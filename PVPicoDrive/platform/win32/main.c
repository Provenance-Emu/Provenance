#include <windows.h>
#include <commdlg.h>
#include <stdio.h>

#include "../../pico/pico.h"
#include "../common/readpng.h"
#include "../common/config.h"
#include "../common/lprintf.h"
#include "../common/emu.h"
#include "../common/menu.h"
#include "../common/input.h"
#include "../common/plat.h"
#include "version.h"
#include "direct.h"
#include "in_vk.h"

char *romname=NULL;
HWND FrameWnd=NULL;
RECT FrameRectMy;
RECT EmuScreenRect = { 0, 0, 320, 224 };
int lock_to_1_1 = 1;
static HWND PicoSwWnd=NULL, PicoPadWnd=NULL;

static HMENU mmain = 0, mdisplay = 0, mpicohw = 0;
static HBITMAP ppad_bmp = 0;
static HBITMAP ppage_bmps[7] = { 0, };
static char rom_name[0x20*3+1];
static int main_wnd_as_pad = 0;

static HANDLE loop_enter_event, loop_end_event;

void error(char *text)
{
  MessageBox(FrameWnd, text, "Error", 0);
}

static void UpdateRect(void)
{
  WINDOWINFO wi;
  memset(&wi, 0, sizeof(wi));
  wi.cbSize = sizeof(wi);
  GetWindowInfo(FrameWnd, &wi);
  FrameRectMy = wi.rcClient;
}

static int extract_rom_name(char *dest, const unsigned char *src, int len)
{
	char *p = dest, s_old = 0x20;
	int i;

	for (i = len - 1; i >= 0; i--)
	{
		if (src[i^1] != ' ') break;
	}
	len = i + 1;

	for (i = 0; i < len; i++)
	{
		unsigned char s = src[i^1];
		if (s == 0x20 && s_old == 0x20) continue;
		else if (s >= 0x20 && s < 0x7f && s != '%')
		{
			*p++ = s;
		}
		else
		{
			sprintf(p, "%%%02x", s);
			p += 3;
		}
		s_old = s;
	}
	*p = 0;

	return p - dest;
}

static void check_name_alias(const char *afname)
{
  char buff[256], *var, *val;
  FILE *f;
  int ret;

  f = fopen(afname, "r");
  if (f == NULL) return;

  while (1)
  {
    ret = config_get_var_val(f, buff, sizeof(buff), &var, &val);
    if (ret ==  0) break;
    if (ret == -1) continue;

    if (strcmp(rom_name, var) == 0) {
      lprintf("rom aliased: \"%s\" -> \"%s\"\n", rom_name, val);
      strncpy(rom_name, val, sizeof(rom_name));
      break;
    }
  }
  fclose(f);
}

static HBITMAP png2hb(const char *fname, int is_480)
{
  BITMAPINFOHEADER bih;
  HBITMAP bmp;
  void *bmem;
  int ret;

  bmem = calloc(1, is_480 ? 480*240*3 : 320*240*3);
  if (bmem == NULL) return NULL;
  ret = readpng(bmem, fname, READPNG_24, is_480 ? 480 : 320, 240);
  if (ret != 0) {
    free(bmem);
    return NULL;
  }

  memset(&bih, 0, sizeof(bih));
  bih.biSize = sizeof(bih);
  bih.biWidth = is_480 ? 480 : 320;
  bih.biHeight = -240;
  bih.biPlanes = 1;
  bih.biBitCount = 24;
  bih.biCompression = BI_RGB;
  bmp = CreateDIBitmap(GetDC(FrameWnd), &bih, CBM_INIT, bmem, (BITMAPINFO *)&bih, 0);
  if (bmp == NULL)
    lprintf("CreateDIBitmap failed with %i", GetLastError());

  free(bmem);
  return bmp;
}

static void PrepareForROM(void)
{
  unsigned char *rom_data = NULL;
  int i, ret, show = PicoAHW & PAHW_PICO;
  
  PicoGetInternal(PI_ROM, (pint_ret_t *) &rom_data);
  EnableMenuItem(mmain, 2, MF_BYPOSITION|(show ? MF_ENABLED : MF_GRAYED));
  ShowWindow(PicoPadWnd, show ? SW_SHOWNA : SW_HIDE);
  ShowWindow(PicoSwWnd, show ? SW_SHOWNA : SW_HIDE);
  CheckMenuItem(mpicohw, 1210, show ? MF_CHECKED : MF_UNCHECKED);
  CheckMenuItem(mpicohw, 1211, show ? MF_CHECKED : MF_UNCHECKED);
  PostMessage(FrameWnd, WM_COMMAND, 1220 + PicoPicohw.page, 0);
  DrawMenuBar(FrameWnd);
  InvalidateRect(PicoSwWnd, NULL, 1);

  PicoPicohw.pen_pos[0] =
  PicoPicohw.pen_pos[1] = 0x8000;
  in_vk_add_pl12 = 0;

  ret = extract_rom_name(rom_name, rom_data + 0x150, 0x20);
  if (ret == 0)
    extract_rom_name(rom_name, rom_data + 0x130, 0x20);

  if (show)
  {
    char path[MAX_PATH], *p;
    GetModuleFileName(NULL, path, sizeof(path) - 32);
    p = strrchr(path, '\\');
    if (p == NULL) p = path;
    else p++;
    if (ppad_bmp == NULL) {
      strcpy(p, "pico\\pad.png");
      ppad_bmp = png2hb(path, 0);
    }

    strcpy(p, "pico\\alias.txt");
    check_name_alias(path);

    for (i = 0; i < 7; i++) {
      if (ppage_bmps[i] != NULL) DeleteObject(ppage_bmps[i]);
      sprintf(p, "pico\\%s_%i.png", rom_name, i);
      ppage_bmps[i] = png2hb(path, 1);
    }
    // games usually don't have page 6, so just duplicate page 5.
    if (ppage_bmps[6] == NULL && ppage_bmps[5] != NULL) {
      sprintf(p, "pico\\%s_5.png", rom_name);
      ppage_bmps[6] = png2hb(path, 1);
    }
  }
}

static void LoadROM(const char *cmdpath)
{
  char rompath[MAX_PATH];
  int ret;

  if (cmdpath != NULL && strlen(cmdpath)) {
    strcpy(rompath, cmdpath + (cmdpath[0] == '\"' ? 1 : 0));
    if (rompath[strlen(rompath)-1] == '\"')
      rompath[strlen(rompath)-1] = 0;
  }
  else {
    OPENFILENAME of; ZeroMemory(&of, sizeof(of));
    rompath[sizeof(rompath) - 1] = 0;
    strncpy(rompath, rom_fname_loaded, sizeof(rompath) - 1);
    of.lStructSize = sizeof(of);
    of.lpstrFilter = "ROMs, CD images\0*.smd;*.bin;*.gen;*.zip;*.32x;*.sms;*.iso;*.cso;*.cue\0"
                     "whatever\0*.*\0";
    of.lpstrFile = rompath;
    of.nMaxFile = MAX_PATH;
    of.Flags = OFN_FILEMUSTEXIST|OFN_HIDEREADONLY;
    of.hwndOwner = FrameWnd;
    if (!GetOpenFileName(&of))
      return;
  }

  if (engineState == PGS_Running) {
    engineState = PGS_Paused;
    WaitForSingleObject(loop_end_event, 5000);
  }

  ret = emu_reload_rom(rompath);
  if (ret == 0) {
    extern char menu_error_msg[]; // HACK..
    error(menu_error_msg);
    return;
  }

  PrepareForROM();
  engineState = PGS_Running;
  SetEvent(loop_enter_event);
}

static const int rect_widths[4]  = { 320, 256, 640, 512 };
static const int rect_heights[4] = { 224, 224, 448, 448 };

// Window proc for the frame window:
static LRESULT CALLBACK WndProc(HWND hwnd,UINT msg,WPARAM wparam,LPARAM lparam)
{
  POINT pt;
  RECT rc;
  int i;
  switch (msg)
  {
    case WM_CLOSE:
      PostQuitMessage(0);
      return 0;
    case WM_DESTROY:
      FrameWnd = NULL; // Blank the handle
      break;
    case WM_SIZE:
    case WM_MOVE:
    case WM_SIZING:
      UpdateRect();
      if (lock_to_1_1 && FrameRectMy.right - FrameRectMy.left != 0 &&
          (FrameRectMy.right - FrameRectMy.left != EmuScreenRect.right - EmuScreenRect.left ||
           FrameRectMy.bottom - FrameRectMy.top != EmuScreenRect.bottom - EmuScreenRect.top)) {
        lock_to_1_1 = 0;
        CheckMenuItem(mdisplay, 1104, MF_UNCHECKED);
      }
      break;
    case WM_COMMAND:
      switch (LOWORD(wparam))
      {
        case 1000:
          LoadROM(NULL);
          break;
        case 1001:
          emu_reset_game();
          return 0;
        case 1002:
          PostQuitMessage(0);
          return 0;
        case 1100:
        case 1101:
        case 1102:
        case 1103:
//          LoopWait=1; // another sync hack
//          for (i = 0; !LoopWaiting && i < 10; i++) Sleep(10);
          FrameRectMy.right  = FrameRectMy.left + rect_widths[wparam&3];
          FrameRectMy.bottom = FrameRectMy.top  + rect_heights[wparam&3];
          AdjustWindowRect(&FrameRectMy, WS_OVERLAPPEDWINDOW, 1);
          MoveWindow(hwnd, FrameRectMy.left, FrameRectMy.top,
            FrameRectMy.right-FrameRectMy.left, FrameRectMy.bottom-FrameRectMy.top, 1);
          UpdateRect();
          lock_to_1_1 = 0;
          CheckMenuItem(mdisplay, 1104, MF_UNCHECKED);
//          if (rom_loaded) LoopWait=0;
          return 0;
        case 1104:
          lock_to_1_1 = !lock_to_1_1;
          CheckMenuItem(mdisplay, 1104, lock_to_1_1 ? MF_CHECKED : MF_UNCHECKED);
          /* FALLTHROUGH */
        case 2000: // EmuScreenRect/FrameRectMy sync request
          if (!lock_to_1_1)
            return 0;
          FrameRectMy.right  = FrameRectMy.left + (EmuScreenRect.right - EmuScreenRect.left);
	  FrameRectMy.bottom = FrameRectMy.top  + (EmuScreenRect.bottom - EmuScreenRect.top);
          AdjustWindowRect(&FrameRectMy, WS_OVERLAPPEDWINDOW, 1);
          MoveWindow(hwnd, FrameRectMy.left, FrameRectMy.top,
            FrameRectMy.right-FrameRectMy.left, FrameRectMy.bottom-FrameRectMy.top, 1);
          UpdateRect();
          return 0;
        case 1210:
        case 1211:
          i = IsWindowVisible((LOWORD(wparam)&1) ? PicoPadWnd : PicoSwWnd);
          i = !i;
          ShowWindow((LOWORD(wparam)&1) ? PicoPadWnd : PicoSwWnd, i ? SW_SHOWNA : SW_HIDE);
          CheckMenuItem(mpicohw, LOWORD(wparam), i ? MF_CHECKED : MF_UNCHECKED);
          return 0;
        case 1212:
          main_wnd_as_pad = !main_wnd_as_pad;
          CheckMenuItem(mpicohw, 1212, main_wnd_as_pad ? MF_CHECKED : MF_UNCHECKED);
          return 0;
        case 1220:
        case 1221:
        case 1222:
        case 1223:
        case 1224:
        case 1225:
        case 1226:
          PicoPicohw.page = LOWORD(wparam) % 10;
          for (i = 0; i < 7; i++)
            CheckMenuItem(mpicohw, 1220 + i, MF_UNCHECKED);
          CheckMenuItem(mpicohw, 1220 + PicoPicohw.page, MF_CHECKED);
          InvalidateRect(PicoSwWnd, NULL, 1);
          return 0;
        case 1300:
          MessageBox(FrameWnd, plat_get_credits(), "About", 0);
          return 0;
      }
      break;
    case WM_TIMER:
      GetCursorPos(&pt);
      GetWindowRect(PicoSwWnd, &rc);
      if (PtInRect(&rc, pt)) break;
      GetWindowRect(PicoPadWnd, &rc);
      if (PtInRect(&rc, pt)) break;
      PicoPicohw.pen_pos[0] |= 0x8000;
      PicoPicohw.pen_pos[1] |= 0x8000;
      in_vk_add_pl12 = 0;
      break;
    case WM_LBUTTONDOWN: in_vk_add_pl12 |=  0x20; return 0;
    case WM_LBUTTONUP:   in_vk_add_pl12 &= ~0x20; return 0;
    case WM_MOUSEMOVE:
      if (!main_wnd_as_pad) break;
      PicoPicohw.pen_pos[0] = 0x03c + (320 * LOWORD(lparam) / (FrameRectMy.right - FrameRectMy.left));
      PicoPicohw.pen_pos[1] = 0x1fc + (232 * HIWORD(lparam) / (FrameRectMy.bottom - FrameRectMy.top));
      SetTimer(FrameWnd, 100, 1000, NULL);
      break;
    case WM_KEYDOWN:
      if (wparam == VK_TAB) {
        emu_reset_game();
	break;
      }
      if (wparam == VK_ESCAPE) {
        LoadROM(NULL);
	break;
      }
      in_vk_keydown(wparam);
      break;
    case WM_KEYUP:
      in_vk_keyup(wparam);
      break;
  }

  return DefWindowProc(hwnd,msg,wparam,lparam);
}

static LRESULT CALLBACK PicoSwWndProc(HWND hwnd,UINT msg,WPARAM wparam,LPARAM lparam)
{
  PAINTSTRUCT ps;
  HDC hdc, hdc2;

  switch (msg)
  {
    case WM_DESTROY: PicoSwWnd=NULL; break;
    case WM_LBUTTONDOWN: in_vk_add_pl12 |=  0x20; return 0;
    case WM_LBUTTONUP:   in_vk_add_pl12 &= ~0x20; return 0;
    case WM_MOUSEMOVE:
      if (HIWORD(lparam) < 0x20) break;
      PicoPicohw.pen_pos[0] = 0x03c + LOWORD(lparam) * 2/3;
      PicoPicohw.pen_pos[1] = 0x2f8 + HIWORD(lparam) - 0x20;
      SetTimer(FrameWnd, 100, 1000, NULL);
      break;
    case WM_KEYDOWN: in_vk_keydown(wparam); break;
    case WM_KEYUP:   in_vk_keyup(wparam);   break;
    case WM_PAINT:
      hdc = BeginPaint(hwnd, &ps);
      if (ppage_bmps[PicoPicohw.page] == NULL)
      {
        SelectObject(hdc, GetStockObject(DEFAULT_GUI_FONT));
        SetTextColor(hdc, RGB(255, 255, 255));
        SetBkColor(hdc, RGB(0, 0, 0));
        TextOut(hdc, 2,  2, "missing PNGs for", 16);
        TextOut(hdc, 2, 18, rom_name, strlen(rom_name));
      }
      else
      {
        hdc2 = CreateCompatibleDC(GetDC(FrameWnd));
        SelectObject(hdc2, ppage_bmps[PicoPicohw.page]);
        BitBlt(hdc, 0, 0, 480, 240, hdc2, 0, 0, SRCCOPY);
        DeleteDC(hdc2);
      }
      EndPaint(hwnd, &ps);
      return 0;
    case WM_CLOSE:
      ShowWindow(hwnd, SW_HIDE);
      CheckMenuItem(mpicohw, 1210, MF_UNCHECKED);
      return 0;
  }

  return DefWindowProc(hwnd,msg,wparam,lparam);
}

static LRESULT CALLBACK PicoPadWndProc(HWND hwnd,UINT msg,WPARAM wparam,LPARAM lparam)
{
  PAINTSTRUCT ps;
  HDC hdc, hdc2;

  switch (msg)
  {
    case WM_DESTROY: PicoPadWnd=NULL; break;
    case WM_LBUTTONDOWN: in_vk_add_pl12 |=  0x20; return 0;
    case WM_LBUTTONUP:   in_vk_add_pl12 &= ~0x20; return 0;
    case WM_MOUSEMOVE:
      PicoPicohw.pen_pos[0] = 0x03c + LOWORD(lparam);
      PicoPicohw.pen_pos[1] = 0x1fc + HIWORD(lparam);
      SetTimer(FrameWnd, 100, 1000, NULL);
      break;
    case WM_KEYDOWN: in_vk_keydown(wparam); break;
    case WM_KEYUP:   in_vk_keyup(wparam);   break;
    case WM_PAINT:
      if (ppad_bmp == NULL) break;
      hdc = BeginPaint(hwnd, &ps);
      hdc2 = CreateCompatibleDC(GetDC(FrameWnd));
      SelectObject(hdc2, ppad_bmp);
      BitBlt(hdc, 0, 0, 320, 240, hdc2, 0, 0, SRCCOPY);
      EndPaint(hwnd, &ps);
      DeleteDC(hdc2);
      return 0;
    case WM_CLOSE:
      ShowWindow(hwnd, SW_HIDE);
      CheckMenuItem(mpicohw, 1211, MF_UNCHECKED);
      return 0;
  }

  return DefWindowProc(hwnd,msg,wparam,lparam);
}


static int FrameInit()
{
  WNDCLASS wc;
  RECT rect={0,0,0,0};
  HMENU mfile;
  int style=0;
  int left=0,top=0,width=0,height=0;

  memset(&wc,0,sizeof(wc));

  // Register the window class:
  wc.lpfnWndProc=WndProc;
  wc.hInstance=GetModuleHandle(NULL);
  wc.hCursor=LoadCursor(NULL,IDC_ARROW);
  wc.hbrBackground=CreateSolidBrush(0);
  wc.lpszClassName="PicoMainFrame";
  RegisterClass(&wc);

  wc.lpszClassName="PicoSwWnd";
  wc.lpfnWndProc=PicoSwWndProc;
  RegisterClass(&wc);

  wc.lpszClassName="PicoPadWnd";
  wc.lpfnWndProc=PicoPadWndProc;
  RegisterClass(&wc);

  rect.right =320;
  rect.bottom=224;

  // Adjust size of windows based on borders:
  style=WS_OVERLAPPEDWINDOW;
  AdjustWindowRect(&rect,style,1);
  width =rect.right-rect.left;
  height=rect.bottom-rect.top;

  // Place window in the centre of the screen:
  SystemParametersInfo(SPI_GETWORKAREA,0,&rect,0);
  left=rect.left+rect.right;
  top=rect.top+rect.bottom;

  left-=width; left>>=1;
  top-=height; top>>=1;

  // Create menu:
  mfile = CreateMenu();
  InsertMenu(mfile, -1, MF_BYPOSITION|MF_STRING, 1000, "&Load ROM");
  InsertMenu(mfile, -1, MF_BYPOSITION|MF_STRING, 1001, "&Reset");
  InsertMenu(mfile, -1, MF_BYPOSITION|MF_STRING, 1002, "E&xit");
  mdisplay = CreateMenu();
  InsertMenu(mdisplay, -1, MF_BYPOSITION|MF_STRING, 1100, "320x224");
  InsertMenu(mdisplay, -1, MF_BYPOSITION|MF_STRING, 1101, "256x224");
  InsertMenu(mdisplay, -1, MF_BYPOSITION|MF_STRING, 1102, "640x448");
  InsertMenu(mdisplay, -1, MF_BYPOSITION|MF_STRING, 1103, "512x448");
  InsertMenu(mdisplay, -1, MF_BYPOSITION|MF_STRING, 1104, "Lock to 1:1");
  mpicohw = CreateMenu();
  InsertMenu(mpicohw, -1, MF_BYPOSITION|MF_STRING, 1210, "Show &Storyware");
  InsertMenu(mpicohw, -1, MF_BYPOSITION|MF_STRING, 1211, "Show &Drawing pad");
  InsertMenu(mpicohw, -1, MF_BYPOSITION|MF_STRING, 1212, "&Main window as pad");
  InsertMenu(mpicohw, -1, MF_BYPOSITION|MF_SEPARATOR, 0, NULL);
  InsertMenu(mpicohw, -1, MF_BYPOSITION|MF_STRING, 1220, "Title page (&0)");
  InsertMenu(mpicohw, -1, MF_BYPOSITION|MF_STRING, 1221, "Page &1");
  InsertMenu(mpicohw, -1, MF_BYPOSITION|MF_STRING, 1222, "Page &2");
  InsertMenu(mpicohw, -1, MF_BYPOSITION|MF_STRING, 1223, "Page &3");
  InsertMenu(mpicohw, -1, MF_BYPOSITION|MF_STRING, 1224, "Page &4");
  InsertMenu(mpicohw, -1, MF_BYPOSITION|MF_STRING, 1225, "Page &5");
  InsertMenu(mpicohw, -1, MF_BYPOSITION|MF_STRING, 1226, "Page &6");
  mmain = CreateMenu();
  InsertMenu(mmain, -1, MF_BYPOSITION|MF_STRING|MF_POPUP, (UINT_PTR) mfile,    "&File");
  InsertMenu(mmain, -1, MF_BYPOSITION|MF_STRING|MF_POPUP, (UINT_PTR) mdisplay, "&Display");
  InsertMenu(mmain, -1, MF_BYPOSITION|MF_STRING|MF_POPUP, (UINT_PTR) mpicohw,  "&Pico");
  EnableMenuItem(mmain, 2, MF_BYPOSITION|MF_GRAYED);
//  InsertMenu(mmain, -1, MF_BYPOSITION|MF_STRING|MF_POPUP, 1200, "&Config");
  InsertMenu(mmain, -1, MF_BYPOSITION|MF_STRING, 1300, "&About");

  // Create the window:
  FrameWnd=CreateWindow("PicoMainFrame","PicoDrive " VERSION,style|WS_VISIBLE,
    left,top,width,height,NULL,mmain,NULL,NULL);

  CheckMenuItem(mdisplay, 1104, lock_to_1_1 ? MF_CHECKED : MF_UNCHECKED);
  ShowWindow(FrameWnd, SW_NORMAL);
  UpdateWindow(FrameWnd);
  UpdateRect();

  // create Pico windows
  style = WS_OVERLAPPED|WS_CAPTION|WS_BORDER|WS_SYSMENU;
  rect.left=rect.top=0;
  rect.right =320;
  rect.bottom=224;

  AdjustWindowRect(&rect,style,1);
  width =rect.right-rect.left;
  height=rect.bottom-rect.top;

  left += 326;
  PicoSwWnd=CreateWindow("PicoSwWnd","Storyware",style,
    left,top,width+160,height,FrameWnd,NULL,NULL,NULL);

  top += 266;
  PicoPadWnd=CreateWindow("PicoPadWnd","Drawing Pad",style,
    left,top,width,height,FrameWnd,NULL,NULL,NULL);

  return 0;
}

// --------------------

static DWORD WINAPI work_thread(void *x)
{
  while (engineState != PGS_Quit) {
    WaitForSingleObject(loop_enter_event, INFINITE);
    if (engineState != PGS_Running)
      continue;

    printf("loop..\n");
    emu_loop();
    SetEvent(loop_end_event);
  }

  return 0;
}

// XXX: use main.c
void xxinit(void)
{
  /* in_init() must go before config, config accesses in_ fwk */
  in_init();
  emu_prep_defconfig();
  emu_read_config(NULL, 0);
  config_readlrom(PicoConfigFile);

  plat_init();
  in_probe();

  emu_init();
  menu_init();
}


int WINAPI WinMain(HINSTANCE p1, HINSTANCE p2, LPSTR cmdline, int p4)
{
  MSG msg;
  DWORD tid = 0;
  HANDLE thread;
  int ret;

  xxinit();
  FrameInit();
  ret = DirectInit();
  if (ret)
    goto end0;

  loop_enter_event = CreateEvent(NULL, 0, 0, NULL);
  if (loop_enter_event == NULL)
    goto end0;

  loop_end_event = CreateEvent(NULL, 0, 0, NULL);
  if (loop_end_event == NULL)
    goto end0;

  thread = CreateThread(NULL, 0, work_thread, NULL, 0, &tid);
  if (thread == NULL)
    goto end0;

  LoadROM(cmdline);

  // Main window loop:
  for (;;)
  {
    GetMessage(&msg,NULL,0,0);
    if (msg.message==WM_QUIT) break;

    TranslateMessage(&msg);
    DispatchMessage(&msg);
  }

  // Signal thread to quit and wait for it to exit:
  if (engineState == PGS_Running) {
    engineState = PGS_Quit;
    WaitForSingleObject(loop_end_event, 5000);
  }
  CloseHandle(thread); thread=NULL;

  emu_write_config(0);
  emu_finish();
  //plat_finish();

end0:
  DirectExit();
  DestroyWindow(FrameWnd);

//  _CrtDumpMemoryLeaks();
  return 0;
}

