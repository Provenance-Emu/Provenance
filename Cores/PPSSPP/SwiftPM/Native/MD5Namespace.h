#pragma once

// PPSSPP and RetroAchievements use different context layouts for md5_finish.
// Apply this to both PPSSPP translation units that call the incremental API.
#define md5_finish PVPPSSPP_md5_finish
