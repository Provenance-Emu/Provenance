//============================================================================
//
//   SSSS    tt          lll  lll
//  SS  SS   tt           ll   ll
//  SS     tttttt  eeee   ll   ll   aaaa
//   SSSS    tt   ee  ee  ll   ll      aa
//      SS   tt   eeeeee  ll   ll   aaaaa  --  "An Atari 2600 VCS Emulator"
//  SS  SS   tt   ee      ll   ll  aa  aa
//   SSSS     ttt  eeeee llll llll  aaaaa
//
// Copyright (c) 1995-2024 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//============================================================================

#ifndef HIGHSCORES_MANAGER_HXX
#define HIGHSCORES_MANAGER_HXX

#define HIGHSCORE_HEADER "06050000highscores"

class OSystem;

#include "Props.hxx"
#include "json_lib.hxx"
#include "FSNode.hxx"
#include "repository/CompositeKeyValueRepository.hxx"
#include "repository/CompositeKeyValueRepositoryNoop.hxx"

using json = nlohmann::json;

/**
  This class provides an interface to all things related to high scores.

  @author  Thomas Jentzsch
*/

namespace HSM {
  static constexpr uInt32 MAX_SCORE_DIGITS = 8;
  static constexpr uInt32 MAX_ADDR_CHARS = MAX_SCORE_DIGITS / 2;
  static constexpr uInt32 MAX_SCORE_ADDR = 4;
  static constexpr uInt32 MAX_SPECIAL_NAME = 5;
  static constexpr uInt32 MAX_SPECIAL_DIGITS = 3;

  static constexpr uInt32 DEFAULT_VARIATION = 1;
  static constexpr uInt32 DEFAULT_ADDRESS = 0;

  static constexpr Int32 NO_VALUE = -1;

  using ScoreAddresses = array<Int16, MAX_SCORE_ADDR>;

  static constexpr uInt32 NUM_RANKS = 10;

  struct ScoresProps {
    // Formats
    uInt32 numDigits{0};
    uInt32 trailingZeroes{0};
    bool scoreBCD{false};
    bool scoreInvert{false};
    bool varsBCD{false};
    bool varsZeroBased{false};
    string special;
    bool specialBCD{false};
    bool specialZeroBased{false};
    string notes;
    // Addresses
    ScoreAddresses scoreAddr;
    uInt16 varsAddr{0};
    uInt16 specialAddr{0};
  };

  struct ScoreEntry {
    Int32 score{0};
    Int32 special{0};
    string name;
    string date;
  };

  struct ScoresData {
    Int32 variation{0};
    string md5;
    ScoreEntry scores[NUM_RANKS];
  };
} // namespace HSM

/**
  This class provides an interface to define, load and save scores. It is meant
  for games which do not support saving highscores.

  @author  Thomas Jentzsch
*/

class HighScoresManager
{
  public:
    explicit HighScoresManager(OSystem& osystem);
    virtual ~HighScoresManager() = default;

    void setRepository(shared_ptr<CompositeKeyValueRepositoryAtomic> repo);

    // check if high score data has been defined
    bool enabled() const;

    /**
      Get the highscore data of game's properties

      @return True if highscore data exists, else false
    */
    bool get(const Properties& props, uInt32& numVariations,
             HSM::ScoresProps& info) const;
    /**
      Set the highscore data of game's properties
    */
    static void set(Properties& props, uInt32 numVariations,
                    const HSM::ScoresProps& info);

    /**
      Calculate the score from given parameters

      @return The current score or -1 if no valid data exists
    */
    Int32 score(uInt32 numAddrBytes, uInt32 trailingZeroes, bool isBCD,
                const HSM::ScoreAddresses& scoreAddr) const;

    // Convert the given value, using only the maximum bits required by maxVal
    //  and adjusted for BCD and zero based data
    static Int32 convert(Int32 val, uInt32 maxVal, bool isBCD, bool zeroBased);

    /**
      Calculate the number of bytes for one player's score from given parameters

      @return The number of score address bytes
    */
    static uInt32 numAddrBytes(Int32 digits, Int32 trailing) {
      return (digits - trailing + 1) / 2;
    }

    // Retrieve current values (using game's properties)
    Int32 numVariations() const;
    string specialLabel() const;
    Int32 variation() const;
    Int32 score() const;
    string formattedScore(Int32 score, Int32 width = -1) const;
    bool scoreInvert() const;
    Int32 special() const;
    string notes() const;

    // Get md5 property definition checksum
    string md5Props() const;

    // Peek into memory
    Int16 peek(uInt16 addr) const;

    void loadHighScores(HSM::ScoresData& data);
    void saveHighScores(HSM::ScoresData& data) const;

  private:
    static const string VARIATIONS_COUNT;
    static const string VARIATIONS_ADDRESS;
    static const string VARIATIONS_BCD;
    static const string VARIATIONS_ZERO_BASED;
    static const string SCORE_DIGITS;
    static const string SCORE_TRAILING_ZEROES;
    static const string SCORE_BCD;
    static const string SCORE_INVERTED;
    static const string SCORE_ADDRESSES;
    static const string SPECIAL_LABEL;
    static const string SPECIAL_ADDRESS;
    static const string SPECIAL_BCD;
    static const string SPECIAL_ZERO_BASED;
    static const string NOTES;

    static constexpr uInt32 MAX_VARIATIONS = 256;

    static constexpr uInt32 MAX_TRAILING = 3;
    static constexpr uInt32 DEFAULT_DIGITS = 4;
    static constexpr uInt32 DEFAULT_TRAILING = 0;
    static constexpr bool DEFAULT_SCORE_BCD = true;
    static constexpr bool DEFAULT_SCORE_REVERSED = false;
    static constexpr bool DEFAULT_VARS_BCD = true;
    static constexpr bool DEFAULT_VARS_ZERO_BASED = false;
    static constexpr bool DEFAULT_SPECIAL_BCD = true;
    static constexpr bool DEFAULT_SPECIAL_ZERO_BASED = false;

    static const string DATA;
    static const string VERSION;
    static const string MD5;
    static const string VARIATION;
    static const string SCORES;
    static const string SCORE;
    static const string SPECIAL;
    static const string NAME;
    static const string DATE;
    static const string PROPCHECK;
    static const string CHECKSUM;

  private:
    // Retrieve current values from (using given parameters)
    Int32 variation(uInt16 addr, bool varBCD, bool zeroBased, uInt32 numVariations) const;

    // Get individual highscore info from properties
    static uInt32 numVariations(const json& jprops);
    static uInt16 varAddress(const json& jprops);
    static uInt16 specialAddress(const json& jprops);
    static uInt32 numDigits(const json& jprops);
    static uInt32 trailingZeroes(const json& jprops);
    static bool scoreBCD(const json& jprops);
    static bool scoreInvert(const json& jprops);
    static bool varBCD(const json& jprops);
    static bool varZeroBased(const json& jprops);
    static string specialLabel(const json& jprops);
    static bool specialBCD(const json& jprops);
    static bool specialZeroBased(const json& jprops);
    static string notes(const json& jprops);

    // Calculate the number of bytes for one player's score from property parameters
    static uInt32 numAddrBytes(const json& jprops);

    // Get properties
    static json properties(const Properties& props);
    json properties(json& jprops) const;

    // Get value from highscore properties for given key
    static bool getPropBool(const json& jprops, string_view key,
                            bool defVal = false);
    static uInt32 getPropInt(const json& jprops, string_view key,
                             uInt32 defVal = 0);
    static string getPropStr(const json& jprops, string_view key,
                             string_view defVal = "");
    static uInt16 getPropAddr(const json& jprops, string_view key,
                              uInt16 defVal = 0);
    static HSM::ScoreAddresses getPropScoreAddr(const json& jprops);

    static uInt16 fromHexStr(string_view addr);
    static Int32 fromBCD(uInt8 bcd);
    string hash(const HSM::ScoresData& data) const;

    /**
      Loads the current high scores for this game and variation from the given JSON object.

      @param hsData  The JSON to parse
      @param data    The loaded high score data

      @return The result of the load.  True on success, false on failure.
    */
    static bool load(const json& hsData, HSM::ScoresData& data);

    static void clearHighScores(HSM::ScoresData& data);

  private:
    // Reference to the osystem object
    OSystem& myOSystem;

    shared_ptr<CompositeKeyValueRepositoryAtomic> myHighscoreRepository
      = make_shared<CompositeKeyValueRepositoryNoop>();

  private:
    // Following constructors and assignment operators not supported
    HighScoresManager() = delete;
    HighScoresManager(const HighScoresManager&) = delete;
    HighScoresManager(HighScoresManager&&) = delete;
    HighScoresManager& operator=(const HighScoresManager&) = delete;
    HighScoresManager& operator=(HighScoresManager&&) = delete;
};

#endif
