/*  Copyright 2016 Guillaume Duhamel

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

package org.yabause.android;

import java.text.SimpleDateFormat;
import java.text.DateFormat;
import java.text.ParseException;
import java.util.Date;
import java.util.Locale;

class GameInfo
{
    private String system;
    private String company;
    private String itemnum;
    private String version;
    private String date;
    private String cdinfo;
    private String region;
    private String peripheral;
    private String gamename;

    public GameInfo(String system, String company, String itemnum, String version, String date, String cdinfo, String region, String peripheral, String gamename)
    {
        this.system = system;
        this.company = company;
        this.itemnum = itemnum;
        this.version = version;
        this.date = date;
        this.cdinfo = cdinfo;
        this.region = region;
        this.peripheral = peripheral;
        this.gamename = gamename;
    }

    public String getSystem()
    {
        return this.system;
    }

    public String getCompany()
    {
        return this.company;
    }

    public String getItemnum()
    {
        return this.itemnum;
    }

    public String getVersion()
    {
        return this.version;
    }

    public String getDate()
    {
        return this.date;
    }

    public String getCdinfo()
    {
        return this.cdinfo;
    }

    public String getRegion()
    {
        return this.region;
    }

    public String getPeripheral()
    {
        return this.peripheral;
    }

    public String getGamename()
    {
        return this.gamename;
    }

    public String getName()
    {
        return this.gamename.replaceAll("\\s+", " ");
    }

    public String getHumanDate() {
        try {
            SimpleDateFormat sdf = new SimpleDateFormat("MM/dd/yyyy", Locale.US);
            DateFormat df = DateFormat.getDateInstance();
            Date date = sdf.parse(this.date);
            return df.format(date);
        } catch(ParseException exc) {
            return this.date;
        }
    }
}
