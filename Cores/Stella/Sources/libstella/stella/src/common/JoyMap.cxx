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

#include "JoyMap.hxx"
#include "Logger.hxx"
#include "jsonDefinitions.hxx"

using json = nlohmann::json;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void JoyMap::add(const Event::Type event, const JoyMapping& mapping)
{
  myMap[mapping] = event;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void JoyMap::add(const Event::Type event, const EventMode mode, const int button,
                 const JoyAxis axis, const JoyDir adir,
                 const int hat, const JoyHatDir hdir)
{
  add(event, JoyMapping(mode, button, axis, adir, hat, hdir));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void JoyMap::add(const Event::Type event, const EventMode mode, const int button,
                 const int hat, const JoyHatDir hdir)
{
  add(event, JoyMapping(mode, button, hat, hdir));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void JoyMap::erase(const JoyMapping& mapping)
{
  myMap.erase(mapping);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void JoyMap::erase(const EventMode mode, const int button,
                   const JoyAxis axis, const JoyDir adir)
{
  erase(JoyMapping(mode, button, axis, adir));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void JoyMap::erase(const EventMode mode, const int button,
                   const int hat, const JoyHatDir hdir)
{
  erase(JoyMapping(mode, button, hat, hdir));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Event::Type JoyMap::get(const JoyMapping& mapping) const
{
  auto find = myMap.find(mapping);
  if(find != myMap.end())
    return find->second;

  // try without button as modifier
  JoyMapping m = mapping;

  m.button = JOY_CTRL_NONE;

  find = myMap.find(m);
  if(find != myMap.end())
    return find->second;

  return Event::Type::NoType;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Event::Type JoyMap::get(const EventMode mode, const int button,
                        const JoyAxis axis, const JoyDir adir) const
{
  return get(JoyMapping(mode, button, axis, adir));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Event::Type JoyMap::get(const EventMode mode, const int button,
                        const int hat, const JoyHatDir hdir) const
{
  return get(JoyMapping(mode, button, hat, hdir));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool JoyMap::check(const JoyMapping& mapping) const
{
  const auto find = myMap.find(mapping);

  return (find != myMap.end());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool JoyMap::check(const EventMode mode, const int button,
                   const JoyAxis axis, const JoyDir adir,
                   const int hat, const JoyHatDir hdir) const
{
  return check(JoyMapping(mode, button, axis, adir, hat, hdir));
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string JoyMap::getDesc(const Event::Type event, const JoyMapping& mapping)
{
  ostringstream buf;

  // button description
  if(mapping.button != JOY_CTRL_NONE)
    buf << "/B" << mapping.button;

  // axis description
  if(mapping.axis != JoyAxis::NONE)
  {
    buf << "/A";
    switch(mapping.axis)
    {
      case JoyAxis::X: buf << "X"; break;
      case JoyAxis::Y: buf << "Y"; break;
      case JoyAxis::Z: buf << "Z"; break;
      default:         buf << static_cast<int>(mapping.axis); break;
    }

    if(Event::isAnalog(event))
      buf << "+|-";
    else if(mapping.adir == JoyDir::NEG)
      buf << "-";
    else
      buf << "+";
  }

  // hat description
  if(mapping.hat != JOY_CTRL_NONE)
  {
    buf << "/H" << mapping.hat;
    switch(mapping.hdir)
    {
      case JoyHatDir::UP:    buf << "Y+"; break;
      case JoyHatDir::DOWN:  buf << "Y-"; break;
      case JoyHatDir::LEFT:  buf << "X-"; break;
      case JoyHatDir::RIGHT: buf << "X+"; break;
      default:                            break;
    }
  }

  return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
string JoyMap::getEventMappingDesc(int stick, const Event::Type event, const EventMode mode) const
{
  ostringstream buf;

  for (const auto& [_mapping, _event]: myMap)
  {
    if (_event == event && _mapping.mode == mode)
    {
      if(!buf.str().empty())
        buf << ", ";
      buf << "C" << stick << getDesc(event, _mapping);
    }
  }
  return buf.str();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
JoyMap::JoyMappingArray JoyMap::getEventMapping(const Event::Type event, const EventMode mode) const
{
  JoyMappingArray map;

  for (const auto& [_mapping, _event]: myMap)
    if (_event == event && _mapping.mode == mode)
      map.push_back(_mapping);

  return map;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
json JoyMap::saveMapping(const EventMode mode) const
{
  using MapType = std::pair<JoyMapping, Event::Type>;
  std::vector<MapType> sortedMap(myMap.begin(), myMap.end());

  std::sort(sortedMap.begin(), sortedMap.end(),
      [](const MapType& a, const MapType& b)
      {
        // Event::Type first
        if(a.first.button != b.first.button)
          return a.first.button < b.first.button;

        if(a.first.axis != b.first.axis)
          return a.first.axis < b.first.axis;

        if(a.first.adir != b.first.adir)
          return a.first.adir < b.first.adir;

        if(a.first.hat != b.first.hat)
          return a.first.hat < b.first.hat;

        if(a.first.hdir != b.first.hdir)
          return a.first.hdir < b.first.hdir;

        return a.second < b.second;
      }
  );

  json eventMappings = json::array();

  for (const auto& [_mapping, _event]: sortedMap) {
    if(_mapping.mode != mode || _event == Event::NoType) continue;

    json eventMapping = json::object();

    eventMapping["event"] = _event;

    if (_mapping.button != JOY_CTRL_NONE) eventMapping["button"] = _mapping.button;

    if (_mapping.axis != JoyAxis::NONE) {
      eventMapping["axis"] = _mapping.axis;
      eventMapping["axisDirection"] = _mapping.adir;
    }

    if (_mapping.hat != -1) {
      eventMapping["hat"] = _mapping.hat;
      eventMapping["hatDirection"] = _mapping.hdir;
    }

    eventMappings.push_back(eventMapping);
  }

  return eventMappings;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int JoyMap::loadMapping(const json& eventMappings, const EventMode mode)
{
  int i = 0;

  for(const json& eventMapping : eventMappings) {
    const int button = eventMapping.contains("button")
      ? eventMapping.at("button").get<int>()
      : JOY_CTRL_NONE;
    const JoyAxis axis = eventMapping.contains("axis")
      ? eventMapping.at("axis").get<JoyAxis>()
      : JoyAxis::NONE;
    const JoyDir axisDirection = eventMapping.contains("axis")
      ? eventMapping.at("axisDirection").get<JoyDir>()
      : JoyDir::NONE;
    const int hat = eventMapping.contains("hat")
      ? eventMapping.at("hat").get<int>()
      : -1;
    const JoyHatDir hatDirection = eventMapping.contains("hat")
      ? eventMapping.at("hatDirection").get<JoyHatDir>()
      : JoyHatDir::CENTER;

    try {
      // avoid blocking mappings for NoType events
      if(eventMapping.at("event").get<Event::Type>() == Event::NoType)
        continue;

      add(
        eventMapping.at("event").get<Event::Type>(),
        mode,
        button,
        axis,
        axisDirection,
        hat,
        hatDirection
      );

      i++;
    } catch (const json::exception&) {
      Logger::error("ignoring invalid joystick event");
    }
  }

  return i;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
json JoyMap::convertLegacyMapping(string list)
{
  json eventMappings = json::array();

  // Since istringstream swallows whitespace, we have to make the
  // delimiters be spaces
  std::replace(list.begin(), list.end(), '|', ' ');
  std::replace(list.begin(), list.end(), ':', ' ');
  std::replace(list.begin(), list.end(), ',', ' ');

  istringstream buf(list);
  int event = 0, button = 0, axis = 0, adir = 0, hat = 0, hdir = 0;

  while(buf >> event && buf >> button
        && buf >> axis && buf >> adir
        && buf >> hat && buf >> hdir)
  {
    json eventMapping = json::object();

    eventMapping["event"] = static_cast<Event::Type>(event);

    if(button != JOY_CTRL_NONE) eventMapping["button"] = button;

    if(static_cast<JoyAxis>(axis) != JoyAxis::NONE) {
      eventMapping["axis"] = static_cast<JoyAxis>(axis);
      eventMapping["axisDirection"] = static_cast<JoyDir>(adir);
    }

    if(hat != -1) {
      eventMapping["hat"] = hat;
      eventMapping["hatDirection"] = static_cast<JoyHatDir>(hdir);
    }

    eventMappings.push_back(eventMapping);
  }

  return eventMappings;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void JoyMap::eraseMode(const EventMode mode)
{
  for(auto item = myMap.begin(); item != myMap.end();)
    if(item->first.mode == mode) {
      const auto _item = item++;
      erase(_item->first);
    }
    else item++;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void JoyMap::eraseEvent(const Event::Type event, const EventMode mode)
{
  for(auto item = myMap.begin(); item != myMap.end();)
    if(item->second == event && item->first.mode == mode) {
      const auto _item = item++;
      erase(_item->first);
    }
    else item++;
}
