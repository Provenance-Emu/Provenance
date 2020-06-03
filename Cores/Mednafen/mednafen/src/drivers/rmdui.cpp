/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* rmdui.cpp:
**  Copyright (C) 2014-2018 Mednafen Team
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

#include "main.h"
#include "rmdui.h"

#include <trio/trio.h>

struct DiskSelectType
{
 std::string text;

 uint32 drive_idx;
 uint32 state_idx;
 uint32 media_idx;
 uint32 orientation_idx;
};

struct DriveSelectType
{
 bool DiskEjected;
 unsigned DiskSelected;

 DiskSelectType DiskEjectOption;
 std::vector<DiskSelectType> DiskSelectOptions;
};

static std::vector<DriveSelectType> Drives;
static uint32 SelectedDrive;
static bool SupressDiskChangeNotifDisplay;

void RMDUI_Init(MDFNGI* gi, const int which_medium)
{
 const RMD_Layout* rmd = gi->RMD;
 char textbuf[256];

#if 0
 for(size_t i = 0; i < rmd->MediaTypes.size(); i++)
 {
  auto const& mt = rmd->MediaTypes[i];

  MDFN_printf(_("Media Type %zu:\n"), i);
  {
   MDFN_AutoIndent aind(1);

   MDFN_printf(_("Name: %s\n"), mt.Name.c_str());
  }
 }

 for(size_t i = 0; i < rmd->Media.size(); i++)
 {
  auto const& m = rmd->Media[i];

  MDFN_printf(_("Medium %zu:\n"), i);
  {
   MDFN_AutoIndent aind(1);

   MDFN_printf(_("Name: %s\n"), m.Name.c_str());
   MDFN_printf(_("Media Type: %u\n"), m.MediaType);
   if(m.Orientations.size())
   {
    MDFN_printf(_("Orientations:\n"));
    {
     MDFN_AutoIndent aindo(1);

     for(size_t j = 0; j < m.Orientations.size(); j++)
     {
      MDFN_printf(_("Orientation %zu:\n"), j);
      {
       MDFN_AutoIndent aindoi(1);

       MDFN_printf(_("Name: %s\n"), m.Orientations[j].c_str());
      }
     }
    }
   }
  }
 }

 for(size_t i = 0; i < rmd->Drives.size(); i++)
 {
  auto const& dri = rmd->Drives[i];
  MDFN_printf(_("Drive %zu:\n"), i);
  {
   MDFN_AutoIndent aind(1);

   MDFN_printf(_("Name: %s\n"), dri.Name.c_str());
   MDFN_printf(_("Possible States:\n"));
   {
    MDFN_AutoIndent ainds(1);

    for(size_t j = 0; j < dri.PossibleStates.size(); j++)
    {
     auto const& state = dri.PossibleStates[j];

     MDFN_printf(_("State %zu:\n"), j);
     {
      MDFN_AutoIndent aindsi(1);
      MDFN_printf(_("Name: %s\n"), state.Name.c_str());
      MDFN_printf(_("Media Present: %s\n"), state.MediaPresent ? "true" : "false");
      MDFN_printf(_("Media Usable: %s\n"), state.MediaUsable ? "true" : "false");
      MDFN_printf(_("Media Can Change: %s\n"), state.MediaCanChange ? "true" : "false");
     }
    }
   }
 
   MDFN_printf(_("Media Change Delay: %u\n"), dri.MediaMtoPDelay);

   MDFN_printf(_("Defaults:\n"));
   {
    auto const& dridefs = rmd->DrivesDefaults[i];
    MDFN_AutoIndent aindd(1);

    MDFN_printf(_("State: %u\n"), dridefs.State);
    MDFN_printf(_("Medium: %u\n"), dridefs.Media);
    MDFN_printf(_("Orientation: %u\n"), dridefs.Orientation);
   }
  }
 }
#endif


 assert(rmd->Drives.size() == rmd->DrivesDefaults.size());

 SelectedDrive = 0;
 Drives.clear();
 Drives.resize(rmd->Drives.size());

 for(unsigned d = 0; d < rmd->Drives.size(); d++)
 {
  const RMD_Drive* rd = &rmd->Drives[d];
  bool deo_set = false;
  std::vector<DiskSelectType> PUOptions;
  std::vector<DiskSelectType> EmptyOptions;

  Drives[d].DiskEjected = true;
  Drives[d].DiskSelected = 0;

  for(unsigned s = 0; s < rd->PossibleStates.size(); s++)
  {
   const RMD_State* rs = &rd->PossibleStates[s];

   if(!rs->MediaPresent || !rs->MediaUsable)
   {
    trio_snprintf(textbuf, sizeof(textbuf), "%s: %s", rd->Name.c_str(), rs->Name.c_str());

    if(rs->MediaCanChange && !deo_set)
    {
     Drives[d].DiskEjectOption = { textbuf, d, s, 0, 0 };
     deo_set = true;
    }
    else
     EmptyOptions.push_back(DiskSelectType({textbuf, d, s, 0, 0}));
   }
   else //if(rs->MediaPresent && rs->MediaUsable)
   {
    for(unsigned m = 0; m < rmd->Media.size(); m++)
    {
     bool media_compatible = false;

     for(unsigned cm : rmd->Drives[d].CompatibleMedia)
     {
      if(rmd->Media[m].MediaType == cm)
      {
       media_compatible = true;
       break;
      }
     }

     if(media_compatible)
     {
      for(unsigned o = 0; o < rmd->Media[m].Orientations.size() || o == 0; o++)
      {
       if(rmd->Media[m].Orientations.size())
        trio_snprintf(textbuf, sizeof(textbuf), "%s: %s (%s, %s)", rd->Name.c_str(), rs->Name.c_str(), rmd->Media[m].Name.c_str(), rmd->Media[m].Orientations[o].c_str());
       else
        trio_snprintf(textbuf, sizeof(textbuf), "%s: %s (%s)", rd->Name.c_str(), rs->Name.c_str(), rmd->Media[m].Name.c_str());

       PUOptions.push_back(DiskSelectType({textbuf, d, s, m, o}));
      }
     }
    }
   }
  }
  //
  //
  //
  Drives[d].DiskSelectOptions = EmptyOptions;
  Drives[d].DiskSelectOptions.insert(Drives[d].DiskSelectOptions.end(), PUOptions.begin(), PUOptions.end());

  for(size_t i = 0; i < Drives[d].DiskSelectOptions.size(); i++)
  {
   const auto& dso = Drives[d].DiskSelectOptions[i];
   const auto& dd = rmd->DrivesDefaults[d];

   if(dso.state_idx == dd.State && dso.media_idx == dd.Media && dso.orientation_idx == dd.Orientation)
   {
    Drives[d].DiskEjected = false;
    Drives[d].DiskSelected = i;
   }
  }

  if(which_medium == -1)
   Drives[d].DiskEjected = true;
  else if(which_medium >= 0 && Drives[d].DiskSelectOptions.size())
  {
   Drives[d].DiskEjected = false;
   Drives[d].DiskSelected = (std::min<size_t>(which_medium, Drives[d].DiskSelectOptions.size() - 1) + EmptyOptions.size()) % Drives[d].DiskSelectOptions.size();
  }
  //
  //
  //
  SupressDiskChangeNotifDisplay = true;

  if(Drives[d].DiskEjected)
   MDFNI_SetMedia(Drives[d].DiskEjectOption.drive_idx, Drives[d].DiskEjectOption.state_idx, Drives[d].DiskEjectOption.media_idx, Drives[d].DiskEjectOption.orientation_idx);
  else
  {
   DiskSelectType* dta = &Drives[d].DiskSelectOptions[Drives[d].DiskSelected];
   MDFNI_SetMedia(dta->drive_idx, dta->state_idx, dta->media_idx, dta->orientation_idx);
  }
  SupressDiskChangeNotifDisplay = false;
 }
}

void RMDUI_Kill(void)
{
 Drives.clear();
}

void Mednafen::MDFND_MediaSetNotification(uint32 drive_idx, uint32 state_idx, uint32 media_idx, uint32 orientation_idx)
{
 const RMD_Layout* rmd = CurGame->RMD;
 const RMD_Drive* rd = &rmd->Drives[drive_idx];
 const RMD_State* rs = &rd->PossibleStates[state_idx];
 auto& dri = Drives[drive_idx];
 DiskSelectType* dta = NULL;

 if(drive_idx == dri.DiskEjectOption.drive_idx && state_idx == dri.DiskEjectOption.state_idx)
 {
  dri.DiskEjected = true;
  dta = &dri.DiskEjectOption;
 }
 else
 {
  for(unsigned i = 0; i < dri.DiskSelectOptions.size(); i++)
  {
   if(drive_idx != dri.DiskSelectOptions[i].drive_idx)
    continue;

   if(state_idx != dri.DiskSelectOptions[i].state_idx)
    continue;

   if(rs->MediaUsable && rs->MediaPresent)
   {
    if(media_idx != dri.DiskSelectOptions[i].media_idx)
     continue;

    if(rmd->Media[media_idx].Orientations.size())
    {
     if(orientation_idx != dri.DiskSelectOptions[i].orientation_idx)
      continue;
    }
   }

   dri.DiskEjected = false;
   dri.DiskSelected = i;
   dta = &dri.DiskSelectOptions[i];
   break;
  }
 }

 if(dta)
 {
  if(!SupressDiskChangeNotifDisplay)
   MDFN_Notify(MDFN_NOTICE_STATUS, "%s", dta->text.c_str());
 }
 else
  fprintf(stderr, "MDFND_MediaSetNotification() error");
}

void RMDUI_Toggle_InsertEject(void)
{
 if(!CurGame->RMD->Drives.size())
  return;
 //
 //
 //
 auto& dri = Drives[SelectedDrive];

 if(dri.DiskSelectOptions.size())
 {
  DiskSelectType* dta = &dri.DiskEjectOption;

  if(dri.DiskEjected)
   dta = &dri.DiskSelectOptions[dri.DiskSelected];

  MDFNI_SetMedia(dta->drive_idx, dta->state_idx, dta->media_idx, dta->orientation_idx);
 }
 else
  MDFN_Notify(MDFN_NOTICE_STATUS, _("No media available to insert into %s!"), CurGame->RMD->Drives[SelectedDrive].Name.c_str());
}

void RMDUI_SelectDisk(void)
{
 if(!Drives.size())
  return;

 auto& dri = Drives[SelectedDrive];

 if(!dri.DiskEjected)
  return;

 if(!dri.DiskSelectOptions.size())
 {
  MDFN_Notify(MDFN_NOTICE_STATUS, _("No media available to select for %s!"), CurGame->RMD->Drives[SelectedDrive].Name.c_str());
  return;
 }

 dri.DiskSelected = (dri.DiskSelected + 1) % dri.DiskSelectOptions.size();

 {
  const DiskSelectType* dta = &dri.DiskSelectOptions[dri.DiskSelected];
  const RMD_State* rs = &CurGame->RMD->Drives[dta->drive_idx].PossibleStates[dta->state_idx];

  if(rs->MediaPresent && rs->MediaUsable)
  {
   if(CurGame->RMD->Media[dta->media_idx].Orientations.size())
    MDFN_Notify(MDFN_NOTICE_STATUS, _("%s, %s selected."), CurGame->RMD->Media[dta->media_idx].Name.c_str(), CurGame->RMD->Media[dta->media_idx].Orientations[dta->orientation_idx].c_str());
   else
    MDFN_Notify(MDFN_NOTICE_STATUS, _("%s selected."), CurGame->RMD->Media[dta->media_idx].Name.c_str());
  }
  else
  {
   MDFN_Notify(MDFN_NOTICE_STATUS, _("Absence selected."));
  }
 }
}

void RMDUI_SelectDrive(void)
{
 if(!Drives.size())
  return;

 SelectedDrive = (SelectedDrive + 1) % Drives.size();
 //
 //
 //
 auto& dri = Drives[SelectedDrive];
 const char* t = dri.DiskEjected ? dri.DiskEjectOption.text.c_str() : dri.DiskSelectOptions[dri.DiskSelected].text.c_str();

 MDFN_Notify(MDFN_NOTICE_STATUS, _("%s selected(%s)."), CurGame->RMD->Drives[SelectedDrive].Name.c_str(), t);
}
