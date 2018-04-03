/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* rmdui.cpp:
**  Copyright (C) 2014-2017 Mednafen Team
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

static bool DiskEjected;
static unsigned DiskSelected;

struct DiskSelectType
{
 std::string text;

 uint32 drive_idx;
 uint32 state_idx;
 uint32 media_idx;
 uint32 orientation_idx;
};

static DiskSelectType DiskEjectOption;
static std::vector<DiskSelectType> DiskSelectOptions;
static bool SupressDiskChangeNotifDisplay;

void RMDUI_Init(MDFNGI* gi, const int which_medium)
{
 const RMD_Layout* rmd = gi->RMD;
 char textbuf[256];
 bool deo_set = false;
 std::vector<DiskSelectType> PUOptions;
 std::vector<DiskSelectType> EmptyOptions;

 assert(rmd->Drives.size() == rmd->DrivesDefaults.size());

 DiskEjected = true;
 DiskSelected = 0;

 for(unsigned d = 0; d < rmd->Drives.size() && d < 1; d++)
 {
  const RMD_Drive* rd = &rmd->Drives[d];

  for(unsigned s = 0; s < rd->PossibleStates.size(); s++)
  {
   const RMD_State* rs = &rd->PossibleStates[s];

   if(!rs->MediaPresent || !rs->MediaUsable)
   {
    trio_snprintf(textbuf, sizeof(textbuf), "%s: %s", rd->Name.c_str(), rs->Name.c_str());

    if(rs->MediaCanChange && !deo_set)
    {
     DiskEjectOption = { textbuf, d, s, 0, 0 };
     deo_set = true;
    }
    else
     EmptyOptions.push_back(DiskSelectType({textbuf, d, s, 0, 0}));
   }
   else //if(rs->MediaPresent && rs->MediaUsable)
   {
    for(unsigned m = 0; m < rmd->Media.size(); m++)
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
 DiskSelectOptions = EmptyOptions;
 DiskSelectOptions.insert(DiskSelectOptions.end(), PUOptions.begin(), PUOptions.end());

 for(size_t i = 0; i < DiskSelectOptions.size(); i++)
 {
  const auto& dso = DiskSelectOptions[i];
  const auto& dd = rmd->DrivesDefaults[0];

  if(dso.state_idx == dd.State && dso.media_idx == dd.Media && dso.orientation_idx == dd.Orientation)
  {
   DiskEjected = false;
   DiskSelected = i;
  }
 }

 if(which_medium == -1)
  DiskEjected = true;
 else if(which_medium >= 0 && DiskSelectOptions.size())
 {
  DiskEjected = false;
  DiskSelected = (std::min<size_t>(which_medium, DiskSelectOptions.size() - 1) + EmptyOptions.size()) % DiskSelectOptions.size();
 }

 SupressDiskChangeNotifDisplay = true;
 if(rmd->Drives.size())
 {
  if(DiskEjected)
   MDFNI_SetMedia(DiskEjectOption.drive_idx, DiskEjectOption.state_idx, DiskEjectOption.media_idx, DiskEjectOption.orientation_idx);
  else
  {
   DiskSelectType* dta = &DiskSelectOptions[DiskSelected];
   MDFNI_SetMedia(dta->drive_idx, dta->state_idx, dta->media_idx, dta->orientation_idx);
  }
 }
 SupressDiskChangeNotifDisplay = false;
}

void RMDUI_Kill(void)
{


}

void MDFND_MediaSetNotification(uint32 drive_idx, uint32 state_idx, uint32 media_idx, uint32 orientation_idx)
{
 const RMD_Layout* rmd = CurGame->RMD;
 const RMD_Drive* rd = &rmd->Drives[drive_idx];
 const RMD_State* rs = &rd->PossibleStates[state_idx];
 DiskSelectType* dta = NULL;

 if(drive_idx == DiskEjectOption.drive_idx && state_idx == DiskEjectOption.state_idx)
 {
  DiskEjected = true;
  dta = &DiskEjectOption;
 }
 else
 {
  for(unsigned i = 0; i < DiskSelectOptions.size(); i++)
  {
   if(drive_idx != DiskSelectOptions[i].drive_idx)
    continue;

   if(state_idx != DiskSelectOptions[i].state_idx)
    continue;

   if(rs->MediaUsable && rs->MediaPresent)
   {
    if(media_idx != DiskSelectOptions[i].media_idx)
     continue;

    if(rmd->Media[media_idx].Orientations.size())
    {
     if(orientation_idx != DiskSelectOptions[i].orientation_idx)
      continue;
    }
   }

   DiskEjected = false;
   DiskSelected = i;
   dta = &DiskSelectOptions[i];
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

 DiskSelectType* dta = &DiskEjectOption;

 if(DiskEjected)
  dta = &DiskSelectOptions[DiskSelected];

 MDFNI_SetMedia(dta->drive_idx, dta->state_idx, dta->media_idx, dta->orientation_idx);
}

void RMDUI_Select(void)
{
 if(!DiskEjected)
  return;

 if(!DiskSelectOptions.size())
  return;

 DiskSelected = (DiskSelected + 1) % DiskSelectOptions.size();

 {
  const DiskSelectType* dta = &DiskSelectOptions[DiskSelected];
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

