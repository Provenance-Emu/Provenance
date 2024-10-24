/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* settings.cpp:
**  Copyright (C) 2005-2023 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

/*
 TODO: Setting changed callback on override setting loading/clearing.
*/

#include "mednafen.h"
#include <mednafen/string/string.h>
#include <mednafen/Time.h>
#include <mednafen/FileStream.h>
#include <mednafen/MemoryStream.h>
#include "settings.h"

#include <locale.h>

namespace Mednafen
{

SettingsManager::SettingsManager()
{

}

SettingsManager::~SettingsManager()
{
 Kill();
}

static INLINE unsigned TranslateSettingValueUI(const char* v, uint64& tlated)
{
 unsigned error = 0;

 // Backwards-compat:
 v = MDFN_strskipspace(v);
 //
 tlated = MDFN_u64fromstr(v, 0, &error);

 return error;
}

static INLINE unsigned TranslateSettingValueI(const char* v, int64& tlated)
{
 unsigned error = 0;

 // Backwards-compat:
 v = MDFN_strskipspace(v);
 //
 tlated = MDFN_s64fromstr(v, 0, &error);
 
 return error;
}

//
// This function is a ticking time bomb of (semi-non-reentrant) wrong, but it's OUR ticking time bomb.
//
// Note to self: test it with something like: LANG="fr_FR.UTF-8" ./mednafen
//
// noinline for *potential* x87 FPU extra precision weirdness in regards to optimizations.
static NO_INLINE bool MR_StringToDouble(const char* string_value, double* dvalue)
{
 static char MR_Radix = 0;
 const unsigned slen = strlen(string_value);
 char cpi_array[256 + 1];
 std::unique_ptr<char[]> cpi_heap;
 char* cpi = cpi_array;
 char* endptr = nullptr;

 if(slen > 256)
 {
  cpi_heap.reset(new char[slen + 1]);
  cpi = cpi_heap.get();
 }

 if(!MR_Radix)
 {
  char buf[64]; // Use extra-large buffer since we're using sprintf() instead of snprintf() for portability reasons. //4];
  // Use libc snprintf() and not trio_snprintf() here for out little abomination.
  //snprintf(buf, 4, "%.1f", (double)1);
  sprintf(buf, "%.1f", (double)1);
  if(buf[0] == '1' && buf[2] == '0' && buf[3] == 0)
  {
   MR_Radix = buf[1];
  }
  else
  {
   lconv* l = localeconv();
   assert(l != nullptr);
   MR_Radix = *(l->decimal_point);
  }
 }

 for(unsigned i = 0; i < slen; i++)
 {
  char c = string_value[i];

  if(c == '.' || c == ',')
   c = MR_Radix;

  cpi[i] = c;
 }
 cpi[slen] = 0;

 *dvalue = strtod(cpi, &endptr);

 if(endptr == nullptr || *endptr != 0 || !*cpi)
  return false;

 return true;
}

static void ValidateSetting(const char *value, const MDFNSetting *setting)
{
 MDFNSettingType base_type = setting->type;

 if(base_type == MDFNST_UINT)
 {
  uint64 ullvalue;

  switch(TranslateSettingValueUI(value, ullvalue))
  {
   case XFROMSTR_ERROR_NONE:
	break;

   case XFROMSTR_ERROR_UNDERFLOW:	// Shouldn't happen
	throw MDFN_Error(0, _("Setting \"%s\" value \"%s\" is too small; the minimum acceptable value is \"%s\"."), setting->name, value, setting->minimum ? setting->minimum : "0");

   case XFROMSTR_ERROR_OVERFLOW:
	throw MDFN_Error(0, _("Setting \"%s\" value \"%s\" is too large; the maximum acceptable value is \"%s\"."), setting->name, value, setting->maximum ? setting->maximum : "18446744073709551615");

   default:
	throw MDFN_Error(0, _("Setting \"%s\" value \"%s\" is not a valid integer."), setting->name, value);
  }

  if(setting->minimum)
  {
   uint64 minimum;

   if(MDFN_UNLIKELY(TranslateSettingValueUI(setting->minimum, minimum)))
    throw MDFN_Error(0, _("Minimum value \"%s\" for setting \"%s\" is invalid."), setting->minimum, setting->name);

   if(MDFN_UNLIKELY(ullvalue < minimum))
    throw MDFN_Error(0, _("Setting \"%s\" value \"%s\" is too small; the minimum acceptable value is \"%s\"."), setting->name, value, setting->minimum);
  }

  if(setting->maximum)
  {
   uint64 maximum;

   if(MDFN_UNLIKELY(TranslateSettingValueUI(setting->maximum, maximum)))
    throw MDFN_Error(0, _("Maximum value \"%s\" for setting \"%s\" is invalid."), setting->maximum, setting->name);

   if(MDFN_UNLIKELY(ullvalue > maximum))
    throw MDFN_Error(0, _("Setting \"%s\" value \"%s\" is too large; the maximum acceptable value is \"%s\"."), setting->name, value, setting->maximum);
  }
 }
 else if(base_type == MDFNST_INT)
 {
  int64 llvalue;

  switch(TranslateSettingValueI(value, llvalue))
  {
   case XFROMSTR_ERROR_NONE:
	break;

   case XFROMSTR_ERROR_UNDERFLOW:
	throw MDFN_Error(0, _("Setting \"%s\" value \"%s\" is too small; the minimum acceptable value is \"%s\"."), setting->name, value, setting->minimum ? setting->minimum : "-9223372036854775808");

   case XFROMSTR_ERROR_OVERFLOW:
	throw MDFN_Error(0, _("Setting \"%s\" value \"%s\" is too large; the maximum acceptable value is \"%s\"."), setting->name, value, setting->maximum ? setting->maximum : "9223372036854775807");

   default:
	throw MDFN_Error(0, _("Setting \"%s\" value \"%s\" is not a valid integer."), setting->name, value);
  }

  if(setting->minimum)
  {
   int64 minimum;

   if(MDFN_UNLIKELY(TranslateSettingValueI(setting->minimum, minimum)))
    throw MDFN_Error(0, _("Minimum value \"%s\" for setting \"%s\" is invalid."), setting->minimum, setting->name);

   if(MDFN_UNLIKELY(llvalue < minimum))
    throw MDFN_Error(0, _("Setting \"%s\" value \"%s\" is too small; the minimum acceptable value is \"%s\"."), setting->name, value, setting->minimum);
  }

  if(setting->maximum)
  {
   int64 maximum;

   if(MDFN_UNLIKELY(TranslateSettingValueI(setting->maximum, maximum)))
    throw MDFN_Error(0, _("Maximum value \"%s\" for setting \"%s\" is invalid."), setting->maximum, setting->name);

   if(MDFN_UNLIKELY(llvalue > maximum))
    throw MDFN_Error(0, _("Setting \"%s\" value \"%s\" is too large; the maximum acceptable value is \"%s\"."), setting->name, value, setting->maximum);
  }
 }
 else if(base_type == MDFNST_FLOAT)
 {
  double dvalue;

  if(!MR_StringToDouble(value, &dvalue) || std::isnan(dvalue))
   throw MDFN_Error(0, _("Setting \"%s\" value \"%s\" is not a valid real number."), setting->name, value);

  if(setting->minimum)
  {
   double minimum;

   if(MDFN_UNLIKELY(!MR_StringToDouble(setting->minimum, &minimum)))
    throw MDFN_Error(0, _("Minimum value \"%s\" for setting \"%s\" is invalid."), setting->minimum, setting->name);

   if(MDFN_UNLIKELY(dvalue < minimum))
    throw MDFN_Error(0, _("Setting \"%s\" value \"%s\" is too small; the minimum acceptable value is \"%s\"."), setting->name, value, setting->minimum);
  }

  if(setting->maximum)
  {
   double maximum;

   if(MDFN_UNLIKELY(!MR_StringToDouble(setting->maximum, &maximum)))
    throw MDFN_Error(0, _("Maximum value \"%s\" for setting \"%s\" is invalid."), setting->maximum, setting->name);

   if(MDFN_UNLIKELY(dvalue > maximum))
    throw MDFN_Error(0, _("Setting \"%s\" value \"%s\" is too large; the maximum acceptable value is \"%s\"."), setting->name, value, setting->maximum);
  }
 }
 else if(base_type == MDFNST_BOOL)
 {
  if(MDFN_UNLIKELY((value[0] != '0' && value[0] != '1') || value[1] != 0))
   throw MDFN_Error(0, _("Setting \"%s\" value \"%s\" is not a valid boolean."), setting->name, value);
 }
 else if(base_type == MDFNST_ENUM)
 {
  const MDFNSetting_EnumList *enum_list = setting->enum_list;
  bool found = false;
  std::string valid_string_list;

  assert(enum_list);

  while(enum_list->string)
  {
   if(!MDFN_strazicmp(value, enum_list->string))
   {
    found = true;
    break;
   }

   if(enum_list->description)	// Don't list out undocumented and deprecated values.
    valid_string_list = valid_string_list + (enum_list == setting->enum_list ? "" : " ") + std::string(enum_list->string);

   enum_list++;
  }

  if(MDFN_UNLIKELY(!found))
   throw MDFN_Error(0, _("Setting \"%s\" value \"%s\" is not a recognized string.  Recognized strings: %s"), setting->name, value, valid_string_list.c_str());
 }
 else if(base_type == MDFNST_MULTI_ENUM)
 {
  std::vector<std::string> mel = MDFN_strsplit(value);

  assert(setting->enum_list);

  for(auto& mee : mel)
  {
   bool found = false;
   const MDFNSetting_EnumList* enum_list = setting->enum_list;

   MDFN_trim(&mee);

   while(enum_list->string)
   {
    if(!MDFN_strazicmp(mee.c_str(), enum_list->string))
    {
     found = true;
     break;
    }
    enum_list++;
   }

   if(!found)
   {
    std::string valid_string_list;

    enum_list = setting->enum_list;
    while(enum_list->string)
    {
     if(enum_list->description)	// Don't list out undocumented and deprecated values.
      valid_string_list = valid_string_list + (enum_list == setting->enum_list ? "" : " ") + std::string(enum_list->string);

     enum_list++;
    }
    throw MDFN_Error(0, _("Setting \"%s\" value \"%s\" component \"%s\" is not a recognized string.  Recognized strings: %s"), setting->name, value, mee.c_str(), valid_string_list.c_str());
   }
  }
 }

 if(setting->validate_func && MDFN_UNLIKELY(!setting->validate_func(setting->name, value)))
 {
  if(base_type == MDFNST_STRING)
   throw MDFN_Error(0, _("Setting \"%s\" value \"%s\" is not an acceptable string."), setting->name, value);
  else
   throw MDFN_Error(0, _("Setting \"%s\" value \"%s\" is not an acceptable integer."), setting->name, value);
 }
}

static uint32 MakeNameHash(const char* name)
{
 uint32 ret = 0;

 for(size_t i = 0; name[i]; i++)
  ret = (ret << 7) - ret + (uint8)name[i]; 

 return ret;
}

INLINE void SettingsManager::ParseSettingLine(char* ls, const char* lb, size_t* valid_count, size_t* unknown_count, unsigned override)
{
 MDFNCS *zesetting;
 char* spacep;

 //
 // Comment
 //
 if(ls[0] == ';' || ls[0] == '#')
  return;

 //
 // Search for first character that may cause MDFN_isspace() to return true
 // (so we can later catch a line like <TAB><SPACE>texthere as being invalid)
 //
 spacep = ls;
 while(spacep != lb)
 {
  if((unsigned char)*spacep <= 0x20)
   break;
  spacep++;
 }

 //
 // No name(key), or no space present, or first special character isn't a space.
 //
 if(spacep == ls || spacep == lb || *spacep != ' ')
 {
  //
  // If any character in the line isn't whitespace, throw an error, otherwise just
  // silently ignore the line.
  //
  for(char* fnonws = ls; fnonws != lb; fnonws++)
  {
   if(MDFN_UNLIKELY(!MDFN_isspace(*fnonws)))
   {
    throw MDFN_Error(0, _("Misformatted setting-value pair \"%.*s\"."), (int)std::min<size_t>(INT_MAX, lb - ls), ls);
   }
  }

  return;
 }

 *spacep = 0;

 zesetting = FindSetting(ls, true);

 if(zesetting)
 {
  char* nv = MDFN_memdupstr(spacep + 1, lb - (spacep + 1));

  if(!nv)
   throw MDFN_Error(ErrnoHolder(ENOMEM));

  ValidateSetting(nv, &zesetting->desc);
  //
  //
  if(zesetting->value[override])
   free(zesetting->value[override]);

  zesetting->value[override] = nv;
  (*valid_count)++;
 }
 else
 {
  if(!override)
  {
   char* tmp;

   *spacep = ' ';
   tmp = MDFN_memdupstr(ls, lb - ls);

   UnknownSettings.push_back(tmp);
  }
  (*unknown_count)++;
 }
}

bool SettingsManager::Load(const std::string& path, unsigned override)
{
 if(!override)
  MDFN_printf(_("Loading settings from \"%s\"...\n"), MDFN_strhumesc(path).c_str());
 else
  MDFN_printf(_("Loading override settings from \"%s\"...\n"), MDFN_strhumesc(path).c_str());

 MDFN_AutoIndent aind(1);

 try
 {
  //
  // MODE_READ_WRITE instead of MODE_READ to allow for locking, and to ensure that the file is writeable.
  //
  MemoryStream mp(new FileStream(path, (override ? FileStream::MODE_READ : FileStream::MODE_READ_WRITE), !override));
  size_t valid_count = 0;
  size_t unknown_count = 0;
  uint32 line_counter = 0;
  //const uint64 st = Time::MonoUS();

  mp.read_utf8_bom();
  //
  try
  {
   char* ls;
   const char* lb;

   while(mp.get_line_mem(&ls, &lb) >= 0)
   {
    if(ls != lb)
     ParseSettingLine(ls, lb, &valid_count, &unknown_count, override);

    line_counter++;
   }
  }
  catch(MDFN_Error& e)
  {
   throw MDFN_Error(e.GetErrno(), _("Line %u: %s"), line_counter + 1, e.what());
  }
  //
  //printf("%llu\n", (unsigned long long)(Time::MonoUS() - st));

  if(override)
   MDFN_printf(_("Loaded %zu valid settings and ignored %zu unknown settings.\n"), valid_count, unknown_count);
  else
   MDFN_printf(_("Loaded %zu valid settings and %zu unknown settings.\n"), valid_count, unknown_count);
 }
 catch(MDFN_Error &e)
 {
  if(e.GetErrno() == ENOENT)
  {
   MDFN_printf(_("Failed: %s\n"), e.what());
   return false;
  }
  else
  {
   throw MDFN_Error(0, _("Failed to load settings from \"%s\": %s"), MDFN_strhumesc(path).c_str(), e.what());
  }
 }
 catch(std::exception &e)
 {
  throw MDFN_Error(0, _("Failed to load settings from \"%s\": %s"), MDFN_strhumesc(path).c_str(), e.what());
 }

 return true;
}

static bool compare_sname(const MDFNCS* first, const MDFNCS* second)
{
 return strcmp(first->desc.name, second->desc.name) < 0;
}

void SettingsManager::Save(const std::string& path)
{
 const size_t num_settings = CurrentSettings.size();
 std::unique_ptr<const MDFNCS*[]> sorted_settings(new const MDFNCS*[num_settings]);

 for(size_t i = 0; i < num_settings; i++)
  sorted_settings[i] = &CurrentSettings[i];

 std::sort(sorted_settings.get(), sorted_settings.get() + num_settings, compare_sname);
 //
 //
 //
 FileStream fp(path, FileStream::MODE_WRITE, true);

 fp.put_string(";VERSION " MEDNAFEN_VERSION "\n");
 fp.put_string(_(";Edit this file at your own risk!\n"));
 fp.put_string(_(";DO NOT EDIT THIS FILE WHILE AN INSTANCE OF MEDNAFEN THAT USES IT IS RUNNING.\n"));
 fp.put_string(_(";File format: <key><single space><value><LF or CR+LF>\n"));

 /* no gettext() for this string, must remain the correct length */
 fp.put_string(";\n;Dummy guard line to prevent settings file corruption by accidentally running ancient versions of Mednafen. Dummy guard line to prevent settings file corruption by accidentally running ancient versions of Mednafen. Dummy guard line to prevent settings file corruption by accidentally running ancient versions of Mednafen. Dummy guard line to prevent settings file corruption by accidentally running ancient versions of Mednafen. Dummy guard line to prevent settings file corruption by accidentally running ancient versions of Mednafen. Dummy guard line to prevent settings file corruption by accidentally running ancient versions of Mednafen. Dummy guard line to prevent settings file corruption by accidentally running ancient versions of Mednafen. Dummy guard line to prevent settings file corruption by accidentally running ancient versions of Mednafen. Dummy guard line to prevent settings file corruption by accidentally running ancient versions of Mednafen.;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;fs ~\n\n");

 for(size_t i = 0; i < num_settings; i++)
 {
  const MDFNCS* lit = sorted_settings[i];

  if(lit->desc.type == MDFNST_ALIAS)
   continue;

  if(lit->desc.flags & MDFNSF_NONPERSISTENT)
   continue;

  fp.put_char(';');
  fp.put_string(_(lit->desc.description));
  fp.put_char('\n');
  fp.put_string(lit->desc.name);
  fp.put_char(' ');
  fp.put_string(lit->value[0]);
  fp.put_char('\n');
  fp.put_char('\n');
 }

 if(UnknownSettings.size())
 {
  fp.put_string("\n;\n;Unrecognized settings follow:\n;\n\n");
  for(size_t i = 0; i < UnknownSettings.size(); i++)
  {
   fp.put_string(UnknownSettings[i]);
   fp.put_char('\n');
   fp.put_char('\n');
  }
 }

 fp.close();
}

void SettingsManager::SaveCompact(Stream* s)
{
 s->put_string(";VERSION " MEDNAFEN_VERSION "\n");

 for(auto const& cse : CurrentSettings)
 {
  s->put_string(cse.desc.name);
  s->put_u8(' ');
  s->put_string(cse.value[0]);
  s->put_u8('\n');
 }

 for(auto const& unke : UnknownSettings)
 {
  s->put_string(unke);
  s->put_u8('\n');
 }
}

INLINE void SettingsManager::MergeSettingSub(const MDFNSetting& setting)
{
 MDFNCS TempSetting;

 assert(setting.name);
 assert(setting.default_value);

#ifdef MDFN_ENABLE_DEV_BUILD
 // Ensure setting name is valid.
 for(const char* s = setting.name; *s; s++)
 {
  const char c = *s;
  bool valid = MDFN_isazlower(c) || (s != setting.name && (MDFN_isdigit(c) || c == '.' || c == '_' || c == '-'));

  if(!valid)
  {
   printf("Bad setting name: %s\n", setting.name);
   abort();
  }
 }
#endif


 TempSetting.name_hash = MakeNameHash(setting.name);
 TempSetting.desc = setting;

 TempSetting.value[0] = strdup(setting.default_value);
 if(!TempSetting.value[0])
  throw MDFN_Error(ErrnoHolder(ENOMEM));

 TempSetting.value[1] = nullptr;
 TempSetting.value[2] = nullptr;
 TempSetting.value[3] = nullptr;

 CurrentSettings.push_back(TempSetting);
}

void SettingsManager::Add(const MDFNSetting& setting)
{
 assert(!SettingsFinalized);

 MergeSettingSub(setting);
}

void SettingsManager::Merge(const MDFNSetting *setting)
{
 assert(!SettingsFinalized);

 while(setting->name != nullptr)
 {
  MergeSettingSub(*setting);
  setting++;
 }
}

static bool CSHashSortFunc(const MDFNCS& a, const MDFNCS& b)
{
 return a.name_hash < b.name_hash;
}

static bool CSHashBoundFunc(const MDFNCS& a, const uint32 b)
{
 return a.name_hash < b;
}

void SettingsManager::Finalize(void)
{
 std::sort(CurrentSettings.begin(), CurrentSettings.end(), CSHashSortFunc);

 //
 // Ensure no duplicates.
 //
 for(size_t i = 0; i < CurrentSettings.size(); i++)
 {
  for(size_t j = i + 1; j < CurrentSettings.size() && CurrentSettings[j].name_hash == CurrentSettings[i].name_hash; j++)
  {
#ifdef MDFN_ENABLE_DEV_BUILD
   MDFN_Notify(MDFN_NOTICE_WARNING, "Setting hash collision: %s %s\n", CurrentSettings[i].desc.name, CurrentSettings[j].desc.name);
#endif

   if(!strcmp(CurrentSettings[i].desc.name, CurrentSettings[j].desc.name))
   {
    printf("Duplicate setting name %s\n", CurrentSettings[j].desc.name);
    abort();
   }
  }
 }

 SettingsFinalized = true;
/*
 for(size_t i = 0; i < CurrentSettings.size(); i++)
 {
  assert(CurrentSettings[i].desc.type == MDFNST_ALIAS || !strcmp(FindSetting(CurrentSettings[i].name)->name, CurrentSettings[i].name));
 }
*/
}

void SettingsManager::ClearOverridesAbove(unsigned clear_above)
{
 assert(clear_above < 4);

 for(auto& sit : CurrentSettings)
 {
  if(sit.desc.type == MDFNST_ALIAS)
   continue;

  for(unsigned i = clear_above + 1; i < 4; i++)
  {
   if(sit.value[i])
   {
    free(sit.value[i]);
    sit.value[i] = nullptr;
   }
  }
 }
}

void SettingsManager::Kill(void)
{
 for(auto& sit : CurrentSettings)
 {
  free(sit.value[0]);

  if(sit.desc.type == MDFNST_ALIAS)
   continue;

  for(unsigned i = 1; i < 4; i++)
  {
   if(sit.value[i])
    free(sit.value[i]);
  }

#if 1
  if(sit.desc.flags & MDFNSF_FREE_NAME)
   free((void*)sit.desc.name);

  if(sit.desc.flags & MDFNSF_FREE_DESC)
   free((void*)sit.desc.description);

  if(sit.desc.flags & MDFNSF_FREE_DESC_EXTRA)
   free((void*)sit.desc.description_extra);

  if(sit.desc.flags & MDFNSF_FREE_DEFAULT)
   free((void*)sit.desc.default_value);

  if(sit.desc.flags & MDFNSF_FREE_MINIMUM)
   free((void*)sit.desc.minimum);

  if(sit.desc.flags & MDFNSF_FREE_MAXIMUM)
   free((void*)sit.desc.maximum);

  if(sit.desc.enum_list)
  {
   if(sit.desc.flags & (MDFNSF_FREE_ENUMLIST_STRING | MDFNSF_FREE_ENUMLIST_DESC | MDFNSF_FREE_ENUMLIST_DESC_EXTRA))
   {
    const MDFNSetting_EnumList* enum_list = sit.desc.enum_list;

    while(enum_list->string)
    {
     if(sit.desc.flags & MDFNSF_FREE_ENUMLIST_STRING)
      free((void*)enum_list->string);

     if(sit.desc.flags & MDFNSF_FREE_ENUMLIST_DESC)
      free((void*)enum_list->description);

     if(sit.desc.flags & MDFNSF_FREE_ENUMLIST_DESC_EXTRA)
      free((void*)enum_list->description_extra);
     //
     enum_list++;
    }
   }
   if(sit.desc.flags & MDFNSF_FREE_ENUMLIST)
    free((void*)sit.desc.enum_list);
  }
#endif
 }

 if(UnknownSettings.size())
 {
  for(size_t i = 0; i < UnknownSettings.size(); i++)
   free(UnknownSettings[i]);
 }
 CurrentSettings.clear();	// Call after the list is all handled
 UnknownSettings.clear();
 SettingsFinalized = false;
}

MDFNCS* SettingsManager::FindSetting(const char* name, bool dont_freak_out_on_fail)
{
 assert(SettingsFinalized);
 //printf("Find: %s\n", name);
 const uint32 name_hash = MakeNameHash(name);
 std::vector<MDFNCS>::iterator it;

 it = std::lower_bound(CurrentSettings.begin(), CurrentSettings.end(), name_hash, CSHashBoundFunc);

 while(it != CurrentSettings.end() && it->name_hash == name_hash)
 {
  if(!strcmp(it->desc.name, name))
  {
   if(it->desc.type == MDFNST_ALIAS)
    return FindSetting(it->value[0], dont_freak_out_on_fail);

   return &*it;
  }
  //printf("OHNOS: %s(%08x) %s(%08x)\n", name, name_hash, it->desc.name, it->name_hash);
  it++;
 }

 if(!dont_freak_out_on_fail)
 {
  printf("\n\nINCONCEIVABLE!  Setting not found: %s\n\n", name);
  exit(1);
 }

 return nullptr;
}

static const char *GetSetting(const MDFNCS *setting)
{
 const char* value;

 if(setting->value[3])
  value = setting->value[3];
 else if(setting->value[2])
  value = setting->value[2];
 else if(setting->value[1])
  value = setting->value[1];
 else
  value = setting->value[0];

 return value;
}

static int GetEnum(const MDFNCS *setting, const char *value)
{
 const MDFNSetting_EnumList *enum_list = setting->desc.enum_list;
 int ret = 0;
 bool found = false;

 assert(enum_list);

 while(enum_list->string)
 {
  if(!MDFN_strazicmp(value, enum_list->string))
  {
   found = true;
   ret = enum_list->number;
   break;
  }
  enum_list++;
 }

 assert(found);
 return ret;
}

template<typename T>
static std::vector<T> GetMultiEnum(const MDFNCS* setting, const char* value)
{
 std::vector<T> ret;
 std::vector<std::string> mel = MDFN_strsplit(value);

 assert(setting->desc.enum_list);

 for(auto& mee : mel)
 {
  const MDFNSetting_EnumList *enum_list = setting->desc.enum_list;
  bool found = false;

  MDFN_trim(&mee);

  while(enum_list->string)
  {
   if(!MDFN_strazicmp(mee.c_str(), enum_list->string))
   {
    found = true;
    ret.push_back(enum_list->number);
    break;
   }
   enum_list++;
  }
  assert(found);
 }

 return ret;
}


uint64 SettingsManager::GetUI(const char *name)
{
 const MDFNCS *setting = FindSetting(name);
 const char *value = GetSetting(setting);

 if(setting->desc.type == MDFNST_ENUM)
  return GetEnum(setting, value);
 else if(setting->desc.type == MDFNST_MULTI_ENUM)
  abort();
 else
 {
  uint64 ret;

  TranslateSettingValueUI(value, ret);

  return ret;
 }
}

int64 SettingsManager::GetI(const char *name)
{
 const MDFNCS *setting = FindSetting(name);
 const char *value = GetSetting(FindSetting(name));

 if(setting->desc.type == MDFNST_ENUM)
  return GetEnum(setting, value);
 else if(setting->desc.type == MDFNST_MULTI_ENUM)
  abort();
 else
 {
  int64 ret;

  TranslateSettingValueI(value, ret);

  return ret;
 }
}

std::vector<uint64> SettingsManager::GetMultiUI(const char *name)
{
 const MDFNCS *setting = FindSetting(name);
 const char *value = GetSetting(setting);

 if(setting->desc.type == MDFNST_MULTI_ENUM)
  return GetMultiEnum<uint64>(setting, value);
 else
  abort();
}

std::vector<int64> SettingsManager::GetMultiI(const char *name)
{
 const MDFNCS *setting = FindSetting(name);
 const char *value = GetSetting(setting);

 if(setting->desc.type == MDFNST_MULTI_ENUM)
  return GetMultiEnum<int64>(setting, value);
 else
  abort();
}

uint64 SettingsManager::GetMultiM(const char *name)
{
 const MDFNCS *setting = FindSetting(name);
 const char *value = GetSetting(setting);
 uint64 ret = 0;

 if(setting->desc.type == MDFNST_MULTI_ENUM)
 {
  std::vector<uint64> tmp = GetMultiEnum<uint64>(setting, value);

  for(uint64 e : tmp)
   ret |= e;
 }
 else
  abort();

 return ret;
}

double SettingsManager::GetF(const char *name)
{
 const MDFNCS *setting = FindSetting(name);
 const char *value = GetSetting(setting);
 double ret = 0;

 if(setting->desc.type == MDFNST_MULTI_ENUM)
  abort();
 else
  MR_StringToDouble(value, &ret);

 return ret;
}

bool SettingsManager::GetB(const char *name)
{
 return (bool)GetUI(name);
}

std::string SettingsManager::GetS(const char *name)
{
 const MDFNCS *setting = FindSetting(name);
 const char *value = GetSetting(setting);

 // Even if we're getting the string value of an enum instead of the associated numeric value, we still need
 // to make sure it's a valid enum
 // (actually, not really, since it's handled in other places where the setting is actually set)
 //if(setting->desc.type == MDFNST_ENUM)
 // GetEnum(setting, value);

 return std::string(value);
}

std::string SettingsManager::GetDefault(const char* name)
{
 const MDFNCS *setting = FindSetting(name);

 return setting->desc.default_value;
}

const std::vector<MDFNCS>* SettingsManager::GetSettings(void)
{
 return &CurrentSettings;
}

bool SettingsManager::Set(const char *name, const char *value, unsigned override)
{
 MDFNCS* zesetting = FindSetting(name, true);

 if(zesetting)
 {
  try
  {
   ValidateSetting(value, &zesetting->desc);
  }
  catch(std::exception &e)
  {
   MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
   return false;
  }

  char* new_value = strdup(value);

  if(!new_value)
  {
   MDFN_Notify(MDFN_NOTICE_ERROR, _("Error allocating memory for setting \"%s\" value."), name);
   return false;
  }

  if(zesetting->value[override])
  {
   free(zesetting->value[override]);
   zesetting->value[override] = nullptr;
  }

  zesetting->value[override] = new_value;

  if(!override)
  {
   for(unsigned i = 1; i < 4; i++)
   {
    if(zesetting->value[i])
    {
     free(zesetting->value[i]);
     zesetting->value[i] = nullptr;
    }
   }
  }

  // TODO, always call driver notification function, regardless of whether a game is loaded.
  if(zesetting->desc.ChangeNotification)
  {
   if(MDFNGameInfo)
    zesetting->desc.ChangeNotification(name);
  }
  return true;
 }
 else
 {
  MDFN_Notify(MDFN_NOTICE_ERROR, _("Unknown setting \"%s\""), name);
  return false;
 }
}

#if 0
// TODO after a game is loaded, but should we?
void MDFN_CallSettingsNotification(void)
{
 for(unsigned int x = 0; x < CurrentSettings.size(); x++)
 {
  if(CurrentSettings[x].desc.ChangeNotification)
  {
   // TODO, always call driver notification function, regardless of whether a game is loaded.
   if(MDFNGameInfo)
    CurrentSettings[x].desc.ChangeNotification(CurrentSettings[x].name);
  }
 }
}
#endif

bool SettingsManager::SetB(const char *name, bool value)
{
 char tmp[2];

 tmp[0] = value ? '1' : '0';
 tmp[1] = 0;

 return Set(name, tmp, false);
}

bool SettingsManager::SetI(const char *name, int64 value)
{
 char tmp[32];

 MDFN_sndec_s64(tmp, sizeof(tmp), value);

 return Set(name, tmp, false);
}

bool SettingsManager::SetUI(const char *name, uint64 value)
{
 char tmp[32];

 MDFN_sndec_u64(tmp, sizeof(tmp), value);

 return Set(name, tmp, false);
}

void SettingsManager::DumpDef(const char *path)
{
 FileStream fp(path, FileStream::MODE_WRITE);
 std::list<const MDFNCS *> SortedList;
 std::list<const MDFNCS *>::iterator lit;
 std::map<int, const char *> tts;
 std::map<uint32, const char *>fts;
 std::map<const char*, std::vector<const char*>> aliases;

 tts[MDFNST_INT] = "MDFNST_INT";
 tts[MDFNST_UINT] = "MDFNST_UINT";
 tts[MDFNST_BOOL] = "MDFNST_BOOL";
 tts[MDFNST_FLOAT] = "MDFNST_FLOAT";
 tts[MDFNST_STRING] = "MDFNST_STRING";
 tts[MDFNST_ENUM] = "MDFNST_ENUM";
 tts[MDFNST_MULTI_ENUM] = "MDFNST_MULTI_ENUM";

 fts[MDFNSF_CAT_INPUT] = "MDFNSF_CAT_INPUT";
 fts[MDFNSF_CAT_SOUND] = "MDFNSF_CAT_SOUND";
 fts[MDFNSF_CAT_VIDEO] = "MDFNSF_CAT_VIDEO";
 fts[MDFNSF_CAT_INPUT_MAPPING] = "MDFNSF_CAT_INPUT_MAPPING";
 fts[MDFNSF_CAT_PATH] = "MDFNSF_CAT_PATH";

 fts[MDFNSF_EMU_STATE] = "MDFNSF_EMU_STATE";
 fts[MDFNSF_UNTRUSTED_SAFE] = "MDFNSF_UNTRUSTED_SAFE";

 fts[MDFNSF_SUPPRESS_DOC] = "MDFNSF_SUPPRESS_DOC";
 fts[MDFNSF_COMMON_TEMPLATE] = "MDFNSF_COMMON_TEMPLATE";
 fts[MDFNSF_NONPERSISTENT] = "MDFNSF_NONPERSISTENT";

 fts[MDFNSF_REQUIRES_RELOAD] = "MDFNSF_REQUIRES_RELOAD";
 fts[MDFNSF_REQUIRES_RESTART] = "MDFNSF_REQUIRES_RESTART";


 for(const auto& sit : CurrentSettings)
 {
  if(sit.desc.type == MDFNST_ALIAS)
  {
   const MDFNCS* c = FindSetting(sit.desc.default_value);

   aliases[c->desc.name].push_back(sit.desc.name);
  }
  else
   SortedList.push_back(&sit);
 }

 SortedList.sort(compare_sname);

 for(lit = SortedList.begin(); lit != SortedList.end(); lit++)
 {
  const MDFNSetting *setting = &(*lit)->desc;

  fp.print_format("%s\n", setting->name);

  for(unsigned int i = 0; i < 32; i++)
  {
   if(setting->flags & (1U << i) & ~MDFNSF_FREE__ANY)
   {
    const char* s = fts[1U << i];
    assert(s);
    fp.print_format("%s ", s);
   }
  }
  fp.print_format("\n");

  fp.print_format("%s\n", MDFN_strescape(setting->description ? setting->description : "").c_str());
  fp.print_format("%s\n", MDFN_strescape(setting->description_extra ? setting->description_extra : "").c_str());

  fp.print_format("%s\n", tts[setting->type]);
  fp.print_format("%s\n", setting->default_value ? setting->default_value : "");
  fp.print_format("%s\n", setting->minimum ? setting->minimum : "");
  fp.print_format("%s\n", setting->maximum ? setting->maximum : "");

  if(!setting->enum_list)
   fp.print_format("0\n");
  else
  {
   const MDFNSetting_EnumList *el = setting->enum_list;
   int count = 0;

   while(el->string) 
   {
    count++;
    el++;
   }

   fp.print_format("%d\n", count);

   el = setting->enum_list;
   while(el->string)
   {
    fp.print_format("%s\n", el->string);
    fp.print_format("%s\n", MDFN_strescape(el->description ? el->description : "").c_str());
    fp.print_format("%s\n", MDFN_strescape(el->description_extra ? el->description_extra : "").c_str());

    el++;
   }
  }

  fp.print_format("%zu\n", aliases[setting->name].size());
  for(const char* al : aliases[setting->name])
   fp.print_format("%s\n", al);
 }

 fp.close();
}

}
