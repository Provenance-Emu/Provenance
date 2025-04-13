// SPDX-FileCopyrightText: Copyright (c) 2024 merryhime <https://mary.rs>
// SPDX-License-Identifier: MIT

#pragma once

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <new>

#if defined(_WIN32)
#    define NOMINMAX
#    include <windows.h>
#elif defined(__APPLE__)
#    include <mach/mach.h>
#    include <mach/vm_map.h>

#    include <TargetConditionals.h>
#    include <libkern/OSCacheControl.h>
#    include <pthread.h>
#    include <sys/mman.h>
#    include <unistd.h>
#else
#    if !defined(_GNU_SOURCE)
#        define _GNU_SOURCE
#    endif
#    include <sys/mman.h>
#    include <sys/types.h>
#    include <unistd.h>
#endif

namespace oaknut {

class DualCodeBlock {
public:
    explicit DualCodeBlock(std::size_t size)
        : m_size(size)
    {
#if defined(_WIN32)
        m_wmem = m_xmem = (std::uint32_t*)VirtualAlloc(nullptr, size, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
        if (m_wmem == nullptr)
            throw std::bad_alloc{};
#elif defined(__APPLE__)
        m_wmem = (std::uint32_t*)mmap(nullptr, size, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
        if (m_wmem == MAP_FAILED)
            throw std::bad_alloc{};

        vm_prot_t cur_prot, max_prot;
        kern_return_t ret = vm_remap(mach_task_self(), (vm_address_t*)&m_xmem, size, 0, VM_FLAGS_ANYWHERE | VM_FLAGS_RANDOM_ADDR, mach_task_self(), (mach_vm_address_t)m_wmem, false, &cur_prot, &max_prot, VM_INHERIT_NONE);
        if (ret != KERN_SUCCESS)
            throw std::bad_alloc{};

        mprotect(m_xmem, size, PROT_READ | PROT_EXEC);
#else
#    if defined(__OpenBSD__)
        char tmpl[] = "oaknut_dual_code_block.XXXXXXXXXX";
        fd = shm_mkstemp(tmpl);
        if (fd < 0)
            throw std::bad_alloc{};
        shm_unlink(tmpl);
#    else
        fd = memfd_create("oaknut_dual_code_block", 0);
        if (fd < 0)
            throw std::bad_alloc{};
#    endif

        int ret = ftruncate(fd, size);
        if (ret != 0)
            throw std::bad_alloc{};

        m_wmem = (std::uint32_t*)mmap(nullptr, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
        m_xmem = (std::uint32_t*)mmap(nullptr, size, PROT_READ | PROT_EXEC, MAP_SHARED, fd, 0);

        if (m_wmem == MAP_FAILED || m_xmem == MAP_FAILED)
            throw std::bad_alloc{};
#endif
    }

    ~DualCodeBlock()
    {
#if defined(_WIN32)
        VirtualFree((void*)m_xmem, 0, MEM_RELEASE);
#elif defined(__APPLE__)
#else
        munmap(m_wmem, m_size);
        munmap(m_xmem, m_size);
        close(fd);
#endif
    }

    DualCodeBlock(const DualCodeBlock&) = delete;
    DualCodeBlock& operator=(const DualCodeBlock&) = delete;
    DualCodeBlock(DualCodeBlock&&) = delete;
    DualCodeBlock& operator=(DualCodeBlock&&) = delete;

    /// Pointer to executable mirror of memory (permissions: R-X)
    std::uint32_t* xptr() const
    {
        return m_xmem;
    }

    /// Pointer to writeable mirror of memory (permissions: RW-)
    std::uint32_t* wptr() const
    {
        return m_wmem;
    }

    /// Invalidate should be used with executable memory pointers.
    void invalidate(std::uint32_t* mem, std::size_t size)
    {
#if defined(__APPLE__)
        sys_icache_invalidate(mem, size);
#elif defined(_WIN32)
        FlushInstructionCache(GetCurrentProcess(), mem, size);
#else
        static std::size_t icache_line_size = 0x10000, dcache_line_size = 0x10000;

        std::uint64_t ctr;
        __asm__ volatile("mrs %0, ctr_el0"
                         : "=r"(ctr));

        const std::size_t isize = icache_line_size = std::min<std::size_t>(icache_line_size, 4 << ((ctr >> 0) & 0xf));
        const std::size_t dsize = dcache_line_size = std::min<std::size_t>(dcache_line_size, 4 << ((ctr >> 16) & 0xf));

        const std::uintptr_t end = (std::uintptr_t)mem + size;

        for (std::uintptr_t addr = ((std::uintptr_t)mem) & ~(dsize - 1); addr < end; addr += dsize) {
            __asm__ volatile("dc cvau, %0"
                             :
                             : "r"(addr)
                             : "memory");
        }
        __asm__ volatile("dsb ish\n"
                         :
                         :
                         : "memory");

        for (std::uintptr_t addr = ((std::uintptr_t)mem) & ~(isize - 1); addr < end; addr += isize) {
            __asm__ volatile("ic ivau, %0"
                             :
                             : "r"(addr)
                             : "memory");
        }
        __asm__ volatile("dsb ish\nisb\n"
                         :
                         :
                         : "memory");
#endif
    }

    void invalidate_all()
    {
        invalidate(m_xmem, m_size);
    }

protected:
#if !defined(_WIN32) && !defined(__APPLE__)
    int fd = -1;
#endif
    std::uint32_t* m_xmem = nullptr;
    std::uint32_t* m_wmem = nullptr;
    std::size_t m_size = 0;
};

}  // namespace oaknut
