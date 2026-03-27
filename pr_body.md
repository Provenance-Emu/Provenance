## Summary

- Replace `vkQueueWaitIdle` (full-queue stall every frame) with per-frame `VkFence` synchronisation in the thin libretro Vulkan bridge
- Add `_vulkanFrameFences[2]` (double-buffer, both pre-signaled at creation) and a `_vulkanFrameIndex` counter
- `get_sync_index` returns the current slot (0 or 1); `get_sync_index_mask` returns 3 (double-buffer; was 1 = single-buffer)
- `wait_sync_index` now uses `vkWaitForFences` on the slot fence instead of `vkQueueWaitIdle`
- `submitVulkanCommandBuffers` resets the fence before submit and waits on it after; advances frame index
- `destroyVulkanDevice` drains the queue then destroys fences before tearing down the device
- Falls back to `vkQueueWaitIdle` automatically if fence functions are unavailable

## Context

Addresses the Vulkan double-buffering item from issue #2624. The original code had an acknowledged comment flagging `vkQueueWaitIdle` as technical debt: "A future improvement would use a VkFence... allowing pipelined rendering without stalling the full queue."

The `vkQueueWaitIdle` stall remains for teardown only (draining the queue before destroying fences). True pipelined CPU/GPU overlap (no stall between submit and MTLTexture extraction) would require deferred-notification via the double-buffer slot and is tracked as a follow-up in issue #2624.

## Test plan

- [ ] Build with `HAVE_VULKAN=1` on iOS; verify no compile errors
- [ ] Run a Vulkan core (Flycast, Beetle PSX HW); frame output should be identical to before
- [ ] Check logs for "double-buffer frame fences created" or fallback "vkQueueWaitIdle" message
- [ ] Confirm no device validation errors with MoltenVK validation layer enabled

Part of #2624
