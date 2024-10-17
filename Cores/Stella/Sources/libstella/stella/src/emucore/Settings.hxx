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

#ifndef SETTINGS_HXX
#define SETTINGS_HXX

#include <map>

#include "Variant.hxx"
#include "bspf.hxx"
#include "repository/KeyValueRepository.hxx"

/**
  This class provides an interface for accessing all configurable options,
  both from the settings file and from the commandline.

  Note that options can be configured as 'permanent' or 'temporary'.
  Permanent options are ones that the app registers with the system, and
  always saves when the app exits.  Temporary options are those that are
  used when appropriate, but never saved to the settings file.

  Each c'tor (both in the base class and in any derived classes) are
  responsible for registering all options as either permanent or temporary.
  If an option isn't registered as permanent, it will be considered
  temporary and will not be saved.

  @author  Stephen Anthony
*/
class Settings
{
  public:
    /**
      Create a new settings abstract class
    */
    explicit Settings();
    virtual ~Settings() = default;

    using Options = std::map<string, Variant, std::less<>>;

    static constexpr int SETTINGS_VERSION = 1;
    static constexpr string_view SETTINGS_VERSION_KEY = "settings.version";

  public:
    /**
      This method should be called to display usage information.
    */
    static void usage();

    void setRepository(shared_ptr<KeyValueRepository> repository);

    /**
      This method is called to load settings from the settings file,
      and apply commandline options specified by the given parameter.

      @param options  A list of options that overrides ones in the
                      settings file
    */
    void load(const Options& options);

    /**
      This method is called to save the current settings to the
      settings file.
    */
    void save();

    /**
      Get the value assigned to the specified key.

      @param key  The key of the setting to lookup
      @return  The value of the setting; EmptyVariant if none exists
    */
    const Variant& value(string_view key) const;

    /**
      Set the value associated with the specified key.

      @param key   The key of the setting
      @param value The value to assign to the key
    */
    void setValue(string_view key, const Variant& value, bool persist = true);

    /**
      Convenience methods to return specific types.

      @param key  The key of the setting to lookup
      @return  The specific type value of the variant
    */
    int getInt(string_view key) const     { return value(key).toInt();   }
    float getFloat(string_view key) const { return value(key).toFloat(); }
    bool getBool(string_view key) const   { return value(key).toBool();  }
    const string& getString(string_view key) const {
      return value(key).toString();
    }
    const Common::Size getSize(string_view key) const {
      return value(key).toSize();
    }
    const Common::Point getPoint(string_view key) const {
      return value(key).toPoint();
    }

  protected:
    /**
      Add key/value pair to specified map.  Note that these should only be called
      directly within the c'tor, to register the 'key' and set it to the
      appropriate 'value'.  Elsewhere, any derived classes should call 'setValue',
      and let it decide where the key/value pair will be saved.
    */
    void setPermanent(string_view key, const Variant& value);
    void setTemporary(string_view key, const Variant& value);

  private:
    /**
      This method must be called *after* settings have been fully loaded
      to validate (and change, if necessary) any improper settings.
    */
    void validate();

    /**
      Migrate settings over one version.
     */
    void migrateOne();

    /**
     Migrate settings.
     */
    void migrate();

  private:
    // Holds key/value pairs that are necessary for Stella to
    // function and must be saved on each program exit.
    Options myPermanentSettings;

    // Holds auxiliary key/value pairs that shouldn't be saved on
    // program exit.
    Options myTemporarySettings;

    shared_ptr<KeyValueRepository> myRespository;

  private:
    // Following constructors and assignment operators not supported
    Settings(const Settings&) = delete;
    Settings(Settings&&) = delete;
    Settings& operator=(const Settings&) = delete;
    Settings& operator=(Settings&&) = delete;
};

#endif
