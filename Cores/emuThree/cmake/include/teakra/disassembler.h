#pragma once

#include <array>
#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace Teakra::Disassembler {

struct ArArpSettings {
    std::array<std::uint16_t, 2> ar;
    std::array<std::uint16_t, 4> arp;
};

bool NeedExpansion(std::uint16_t opcode);
bool NeedExpansion(std::uint16_t opcode);
std::vector<std::string> GetTokenList(std::uint16_t opcode, std::uint16_t expansion = 0,
                                      std::optional<ArArpSettings> ar_arp = std::nullopt);
std::string Do(std::uint16_t opcode, std::uint16_t expansion = 0,
               std::optional<ArArpSettings> ar_arp = std::nullopt);

} // namespace Teakra::Disassembler
