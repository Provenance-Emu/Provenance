-- this includes the iup system
--local iuplua_open = package.loadlib("iuplua51.dll", "iuplua_open");
--if(iuplua_open == nil) then require("libiuplua51"); end
--iuplua_open();

-- this includes the "special controls" of iup (dont change the order though)
--local iupcontrolslua_open = package.loadlib("iupluacontrols51.dll", "iupcontrolslua_open");
--if(iupcontrolslua_open == nil) then require("libiupluacontrols51"); end
--iupcontrolslua_open();
require("iuplua");
--TODO!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
--LUACALL_BEFOREEXIT use that instead of emu.OnClose below

-- callback function to clean up our mess
-- this is called when the script exits (forced or natural)
-- you need to close all the open dialogs here or FCEUX crashes
--function emu.OnClose.iuplua()
	-- gui.popup("OnClose!");
	--if(emu and emu.OnCloseIup ~= nil) then
	--	emu.OnCloseIup();
	--end
	--iup.Close(); 
--end


-- this system allows you to open a number of dialogs without
-- having to bother about cleanup when the script exits
handles = {}; -- this table should hold the handle to all dialogs created in lua
dialogs = 0; -- should be incremented PRIOR to creating a new dialog

-- called by the onclose event (above)
function OnCloseIup()
	if (handles) then -- just in case the user was "smart" enough to clear this
		local i = 1;
		while (handles[i] ~= nil) do -- cycle through all handles, false handles are skipped, nil denotes the end
			if (handles[i] and handles[i].destroy) then -- check for the existence of what we need
				handles[i]:destroy(); -- close this dialog (:close() just hides it)
				handles[i] = nil;
			end;
			i = i + 1;
		end;
	end;
end;

emu.registerexit(OnCloseIup);
