#include "main.h"
#include "console.h"
#include <math.h>
#include "nongl.h"

MDFNConsole::MDFNConsole(bool setshellstyle, unsigned setfont)
{
 prompt_visible = TRUE;
 shellstyle = setshellstyle;
 Scrolled = 0;
 Font = setfont;
 opacity = 0xC0;
}

MDFNConsole::~MDFNConsole()
{
 kb_cursor_pos = 0;
}

bool MDFNConsole::TextHook(const std::string &text)
{
 WriteLine(text);

 return(1);
}

void MDFNConsole::Scroll(int32 amount, bool SetPos)
{
 if(SetPos)
 {
  // Scroll to the beginning
  if(amount == 0)
  {
   //Scrolled = 
  }
  else // Scroll to the end
  {
   Scrolled = 0;
  }
 }
 else
 {
  int64 ts = Scrolled;
  ts += amount;

  if(ts < 0)
   ts = 0;
  Scrolled = ts;
 }
}

#include <mednafen/string/ConvertUTF.h>
int MDFNConsole::Event(const SDL_Event *event)
{
  switch(event->type)
  {
   case SDL_KEYDOWN:
                    if(event->key.keysym.mod & KMOD_ALT)
                     break;
                    switch(event->key.keysym.sym)
                    {
		     case SDLK_HOME:
			if(event->key.keysym.mod & KMOD_SHIFT)
			{
			 Scroll(0, TRUE); // Scroll to the beginning
			}
			else
			 kb_cursor_pos = 0;
			break;
		     case SDLK_END:
			if(event->key.keysym.mod & KMOD_SHIFT)
			{
			 Scroll(-1, TRUE); // Scroll to the end
			}
			else
			 kb_cursor_pos = kb_buffer.size();
			break;
	             case SDLK_LEFT:
	                if(kb_cursor_pos)
	                 kb_cursor_pos--;
	                break;
	             case SDLK_RIGHT:
	                if(kb_cursor_pos < kb_buffer.size())
	                 kb_cursor_pos++;
	                break;

		     case SDLK_UP: 
			if(event->key.keysym.mod & KMOD_SHIFT)
			 Scroll(1); 
			else
			{

			}
			break;
		     case SDLK_DOWN: 
			if(event->key.keysym.mod & KMOD_SHIFT)
			{
			 Scroll(-1); 
			}
			else
			{

			}
			break;

                     case SDLK_RETURN:
                     {
                      std::string concat_str;
                      for(unsigned int i = 0; i < kb_buffer.size(); i++)
                       concat_str += kb_buffer[i];

		      TextHook(strdup(concat_str.c_str()));
                      kb_buffer.clear();
		      kb_cursor_pos = 0;
                     }
                     break;
	           case SDLK_BACKSPACE:
	                if(kb_buffer.size() && kb_cursor_pos)
	                {
	                  kb_buffer.erase(kb_buffer.begin() + kb_cursor_pos - 1, kb_buffer.begin() + kb_cursor_pos);
	                  kb_cursor_pos--;
	                }
	                break;
  	            case SDLK_DELETE:
	                if(kb_buffer.size() && kb_cursor_pos < kb_buffer.size())
	                {
	                 kb_buffer.erase(kb_buffer.begin() + kb_cursor_pos, kb_buffer.begin() + kb_cursor_pos + 1);
	                }
	                break;
                     default:
		     if(event->key.keysym.unicode >= 0x20)
                     {
                      uint8 utf8_buffer[8];
                      UTF8 *dest_ptr = utf8_buffer;
                      memset(utf8_buffer, 0, sizeof(utf8_buffer));
                      const UTF16 *start_utf16 = &event->key.keysym.unicode;
                      ConvertUTF16toUTF8(&start_utf16, (UTF16 *)&event->key.keysym.unicode + 1, &dest_ptr, &utf8_buffer[8], lenientConversion);
	              kb_buffer.insert(kb_buffer.begin() + kb_cursor_pos, std::string((char *)utf8_buffer));
	              kb_cursor_pos++;
                     }
                     break;
                    }
                    break;
  }
 return(1);
}

#define MK_COLOR_A(r,g,b,a) (pf_cache.MakeColor(r,g,b,a))

void MDFNConsole::Draw(MDFN_Surface *surface, const MDFN_Rect *src_rect)
{
 const MDFN_PixelFormat pf_cache = surface->format;
 uint32 pitch32 = surface->pitchinpix;
 uint32 w = src_rect->w;
 uint32 h = src_rect->h;
 uint32 *pixels = surface->pixels + src_rect->x + src_rect->y * pitch32;
 const unsigned int EffFont = Font;
 const unsigned int font_height = GetFontHeight(EffFont);

 MDFN_Surface *tmp_surface = new MDFN_Surface(NULL, 1024, font_height + 1, 1024, surface->format);

 for(unsigned int y = 0; y < h; y++)
 {
  uint32 *row = pixels + y * pitch32;
  for(unsigned int x = 0; x < w; x++)
  {
   //printf("%d %d %d\n", y, x, pixels);
   row[x] = MK_COLOR_A(0, 0, 0, opacity);
   //row[x] = MK_COLOR_A(0x00, 0x00, 0x00, 0x7F);
  }
 }
 int32 destline;
 int32 vec_index = TextLog.size() - 1;

 if(vec_index > 0)
 {
  vec_index -= Scrolled;
 }

 destline = ((h - font_height) / font_height) - 1;

 if(shellstyle)
  vec_index--;
 else if(!prompt_visible)
 {
  destline = (h / font_height) - 1;
  //vec_index--;
 }

 while(destline >= 0 && vec_index >= 0)
 {
  int32 pw = GetTextPixLength(TextLog[vec_index].c_str(), EffFont) + 1;

  if(pw > tmp_surface->w)
  {
   delete tmp_surface;
   tmp_surface = new MDFN_Surface(NULL, pw, font_height + 1, pw, surface->format);
  }

  tmp_surface->Fill(0, 0, 0, opacity);
  DrawTextTransShadow(tmp_surface->pixels, tmp_surface->pitchinpix << 2, tmp_surface->w, TextLog[vec_index].c_str(), MK_COLOR_A(0xff, 0xff, 0xff, 0xFF), MK_COLOR_A(0x00, 0x00, 0x01, 0xFF), 0, EffFont);
  int32 numlines = (uint32)ceil((double)pw / w);

  while(numlines > 0 && destline >= 0)
  {
   int32 offs = (numlines - 1) * w;
   MDFN_Rect tmp_rect, dest_rect;
   tmp_rect.x = offs;
   tmp_rect.y = 0;
   tmp_rect.h = font_height;
   tmp_rect.w = (pw - offs) > (int32)w ? w : pw - offs;

   dest_rect.x = src_rect->x;
   dest_rect.y = src_rect->y + destline * font_height;
   dest_rect.w = tmp_rect.w;
   dest_rect.h = tmp_rect.h;

   MDFN_StretchBlitSurface(tmp_surface, &tmp_rect, surface, &dest_rect);
   numlines--;
   destline--;
  }
  vec_index--;
 }
 delete tmp_surface;

 if(prompt_visible)
 {
  std::string concat_str;

  if(shellstyle)
  {
   int t = TextLog.size() - 1;
   if(t >= 0)
    concat_str = TextLog[t];
   else
    concat_str = "";
  }
  else
   concat_str = "#>";
  for(unsigned int i = 0; i < kb_buffer.size(); i++)
  {
   if(i == kb_cursor_pos && (SDL_GetTicks() & 0x100))
    concat_str += "▉";
   else
    concat_str += kb_buffer[i];
  }

  if(kb_cursor_pos == kb_buffer.size())
  {
   if(SDL_GetTicks() & 0x100)
    concat_str += "▉";
   else
    concat_str += " ";
  }

  {
   uint32 nw = GetTextPixLength(concat_str.c_str()) + 1;
   tmp_surface = new MDFN_Surface(NULL, nw, font_height + 1, nw, surface->format);
   tmp_surface->Fill(0, 0, 0, opacity);
  }

  MDFN_Rect tmp_rect, dest_rect;

  tmp_rect.w = DrawTextTransShadow(tmp_surface->pixels, tmp_surface->pitchinpix << 2, tmp_surface->w, concat_str.c_str(),MK_COLOR_A(0xff, 0xff, 0xff, 0xff), MK_COLOR_A(0x00, 0x00, 0x01, 0xFF), 0, EffFont);
  tmp_rect.h = dest_rect.h = font_height;
  tmp_rect.x = 0;
  tmp_rect.y = 0;

  if(tmp_rect.w >= w)
  {
   tmp_rect.x = tmp_rect.w - w;
   tmp_rect.w -= tmp_rect.x;
  }
  dest_rect.w = tmp_rect.w;
  dest_rect.x = src_rect->x;
  dest_rect.y = src_rect->y + h - (font_height + 1);

  MDFN_StretchBlitSurface(tmp_surface, &tmp_rect, surface, &dest_rect);
  delete tmp_surface;
 }
}

void MDFNConsole::WriteLine(const std::string &text)
{
 TextLog.push_back(text);
}

void MDFNConsole::AppendLastLine(const std::string &text)
{
 if(TextLog.size()) // Should we throw an exception if this isn't true?
  TextLog[TextLog.size() - 1] += text;
}

void MDFNConsole::ShowPrompt(bool shown)
{
 prompt_visible = shown;
}
