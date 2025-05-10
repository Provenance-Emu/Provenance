#pragma once

#include <array>
#include <cstdint>
#include <functional>
#include <memory>

namespace Teakra {

struct AHBMCallback {
    std::function<std::uint8_t(std::uint32_t address)> read8;
    std::function<void(std::uint32_t address, std::uint8_t value)> write8;

    std::function<std::uint16_t(std::uint32_t address)> read16;
    std::function<void(std::uint32_t address, std::uint16_t value)> write16;

    std::function<std::uint32_t(std::uint32_t address)> read32;
    std::function<void(std::uint32_t address, std::uint32_t value)> write32;
};

class Teakra {
public:
    Teakra();
    ~Teakra();

    void Reset();

    std::array<std::uint8_t, 0x80000>& GetDspMemory();
    const std::array<std::uint8_t, 0x80000>& GetDspMemory() const;

    // APBP Data
    bool SendDataIsEmpty(std::uint8_t index) const;
    void SendData(std::uint8_t index, std::uint16_t value);
    bool RecvDataIsReady(std::uint8_t index) const;
    std::uint16_t RecvData(std::uint8_t index);
    std::uint16_t PeekRecvData(std::uint8_t index);
    void SetRecvDataHandler(std::uint8_t index, std::function<void()> handler);

    // APBP Semaphore
    void SetSemaphore(std::uint16_t value);
    void ClearSemaphore(std::uint16_t value);
    void MaskSemaphore(std::uint16_t value);
    void SetSemaphoreHandler(std::function<void()> handler);
    std::uint16_t GetSemaphore() const;

    // for implementing DSP_PDATA/PADR DMA transfers
    std::uint16_t ProgramRead(std::uint32_t address) const;
    void ProgramWrite(std::uint32_t address, std::uint16_t value);
    std::uint16_t DataRead(std::uint16_t address, bool bypass_mmio = false);
    void DataWrite(std::uint16_t address, std::uint16_t value, bool bypass_mmio = false);
    std::uint16_t DataReadA32(std::uint32_t address) const;
    void DataWriteA32(std::uint32_t address, std::uint16_t value);
    std::uint16_t MMIORead(std::uint16_t address);
    void MMIOWrite(std::uint16_t address, std::uint16_t value);

    // DSP_PADR is only 16-bit, so this is where the DMA interface gets the
    // upper 16-bits from
    std::uint16_t DMAChan0GetSrcHigh();
    std::uint16_t DMAChan0GetDstHigh();

    std::uint16_t AHBMGetUnitSize(std::uint16_t i) const;
    std::uint16_t AHBMGetDirection(std::uint16_t i) const;
    std::uint16_t AHBMGetDmaChannel(std::uint16_t i) const;
    // we need these as AHBM does some weird stuff on unaligned accesses internally
    std::uint16_t AHBMRead16(std::uint32_t addr);
    void AHBMWrite16(std::uint32_t addr, std::uint16_t value);
    std::uint16_t AHBMRead32(std::uint32_t addr);
    void AHBMWrite32(std::uint32_t addr, std::uint32_t value);

    // core
    void Run(unsigned cycle);

    void SetAHBMCallback(const AHBMCallback& callback);

    void SetAudioCallback(std::function<void(std::array<std::int16_t, 2>)> callback);

private:
    struct Impl;
    std::unique_ptr<Impl> impl;
};
} // namespace Teakra
