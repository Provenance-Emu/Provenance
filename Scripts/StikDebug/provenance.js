/**
 * provenance.js — StikDebug script for Provenance dynarec cores on iOS 26
 *
 * iOS 26 enforces W×X (Write-XOR-Execute) pages via TXM (Trusted Execution Monitor).
 * Dynarec-based emulator cores (Mupen64Plus, Flycast, ...) emit a `BRK #0x69`
 * instruction immediately before any JIT write sequence to signal that a memory
 * region needs to be prepared for the dual-mapping W×X pattern.
 *
 * When StikDebug intercepts BRK #0x69 it calls this script:
 *   x0 — base address of the JIT code region (RX mapping)
 *   x1 — size of the region in bytes
 *
 * This script asks the TXM debug proxy to authorise execution of the pages and
 * then creates an RW alias via vm_remap so the dynarec can write code through
 * the writable alias while the CPU executes from the read+execute mapping.
 *
 * Usage
 * -----
 * 1. Open StikDebug → Scripts → Import → select this file.
 * 2. Enable the script before attaching to Provenance.
 * 3. Launch Provenance, open a game that uses a dynarec core.
 *    (Mupen64Plus, Flycast on iOS 26 — other interpreter-only cores are unaffected.)
 *
 * The script is a no-op on iOS < 26 because `prepare_memory_region` returns
 * success immediately when TXM is not enforcing W×X.
 *
 * Adapted from ManicEMU manic.js — credits to the ManicEMU contributors.
 *
 * Part of Provenance issue #2792 — JIT UX & Intelligent JIT Management.
 */

"use strict";

// BRK #0x69 — the sentinel instruction emitted by Provenance's dynarec cores
// to trigger W×X page preparation.  Value = 0xD4200D20 on AArch64.
const JIT_BRK_IMMEDIATE = 0x69;

// Memory-protection constants for vm_remap's prot argument.
// These match the POSIX mmap PROT_* values used by the Darwin VM layer.
const PROT_NONE  = 0; // no access
const PROT_READ  = 1; // pages are readable
const PROT_WRITE = 2; // pages are writable
const PROT_RW    = PROT_READ | PROT_WRITE; // read+write (no execute) — for the RW alias

// Whether StikDebug provides register values as BigInt (true on current builds).
// StikDebug ≥ 1.3 returns x0/x1 as BigInt to preserve full 64-bit precision;
// older builds return Number (which loses precision above 2^53).
// We normalise to BigInt for all address arithmetic so large JIT heap addresses
// (which routinely exceed 0x100000000 on 64-bit iOS) are handled correctly.
function toBigInt(v) {
    return (typeof v === "bigint") ? v : BigInt(v >>> 0);
}

/**
 * onBreakpoint — called by StikDebug each time a BRK instruction fires.
 *
 * @param {object} ctx              — CPU register context at the point of the BRK
 *   ctx.x0  (BigInt|Number)   — base address of the JIT region (RX mapping)
 *   ctx.x1  (BigInt|Number)   — size of the region in bytes
 *   ctx.pc  (BigInt|Number)   — program counter (address of the BRK instruction)
 *   ctx.brk (Number)          — immediate encoded in the BRK instruction
 * @param {object} mem   — memory helpers { read, write, alloc, free }
 * @param {object} proc  — process helpers { prepare_memory_region, vm_remap,
 *                         pid, name }
 * @returns {boolean}    — true to resume execution; false to halt the process
 */
function onBreakpoint(ctx, mem, proc) {
    // Only handle our sentinel BRK.
    if (ctx.brk !== JIT_BRK_IMMEDIATE) {
        return true; // Resume — not ours.
    }

    // Normalise to BigInt — iOS 26 JIT heap addresses exceed 2^32 and can
    // exceed 2^53, so JavaScript Number loses integer precision above that
    // threshold.  Using BigInt ensures vm_remap / prepare_memory_region receive
    // the exact 64-bit address and size the dynarec reported.
    const regionBase = toBigInt(ctx.x0);
    const regionSize = toBigInt(ctx.x1);

    if (!regionBase || !regionSize) {
        console.warn("[provenance.js] BRK #0x69 with null base/size — skipping");
        return true;
    }

    console.log(
        "[provenance.js] W×X prepare: base=0x" + regionBase.toString(16) +
        " size=0x" + regionSize.toString(16)
    );

    // Step 1 — Ask TXM to authorise execution of these pages.
    //
    // prepare_memory_region tells the Trusted Execution Monitor that the
    // address range [regionBase, regionBase+regionSize) is a legitimate
    // JIT region authorised by the debugger attachment.  Without this call
    // any attempt to execute freshly-written code pages on iOS 26 will
    // raise a code-signing violation and terminate the process.
    const prepareResult = proc.prepare_memory_region(regionBase, regionSize);
    if (prepareResult !== 0) {
        console.error(
            "[provenance.js] prepare_memory_region failed: " + prepareResult
        );
        // Do not abort the process — fall back gracefully.
        return true;
    }

    // Step 2 — Create an RW alias via vm_remap.
    //
    // vm_remap maps the same physical pages that back regionBase (RX) into a
    // new virtual address with PROT_RW (read+write, no execute) protection.
    // The dynarec writes JIT code through this alias; the CPU executes from
    // the original RX mapping.  This is the dual-mapping (shadow-page) pattern
    // required by the iOS 26 W×X enforcement model.
    const rwAlias = proc.vm_remap(regionBase, regionSize, PROT_RW);
    if (!rwAlias) {
        console.error("[provenance.js] vm_remap failed — JIT write alias not created");
        return true;
    }

    // Pass the RW alias address back to the dynarec via x0.
    // The dynarec must store this and use it for all write operations.
    ctx.x0 = rwAlias;

    console.log(
        "[provenance.js] W×X ready: RX=0x" + regionBase.toString(16) +
        " RW alias=0x" + toBigInt(rwAlias).toString(16)
    );

    return true; // Resume execution.
}

/**
 * onAttach — called once when StikDebug attaches to the process.
 * Use this to set up any one-time state or log version info.
 *
 * @param {object} proc — process info { pid, name, bundleId }
 */
function onAttach(proc) {
    console.log(
        "[provenance.js] attached to " + proc.name +
        " (pid " + proc.pid + ")" +
        " — iOS 26 W×X JIT helper active"
    );
}

/**
 * onDetach — called when the debugger detaches.
 *
 * @param {object} proc — process info
 */
function onDetach(proc) {
    console.log("[provenance.js] detached from " + proc.name);
}
