#include <iostream>
#include <fstream>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <dirent.h>

#include "../../types.h"
#include "configSys.h"

std::string cfgFile = "fceux.cfg";
/**
 * Add a given option.  The option is specified as a short command
 * line (-f), long command line (--foo), option name (Foo), its type
 * (integer or string).
 */
int
Config::_addOption(char shortArg,
                   const std::string &longArg,
                   const std::string &name,
                   int type)
{
    // make sure we have a valid type
    if(type != INTEGER && type != STRING &&
       type != DOUBLE && type != FUNCTION) {
        return -1;
    }

    // check if the option already exists
    if(_shortArgMap.find(shortArg) != _shortArgMap.end() ||
       _longArgMap.find(longArg) != _longArgMap.end() ||
       (type == INTEGER && _intOptMap.find(name) != _intOptMap.end()) ||
       (type == STRING  && _strOptMap.find(name) != _strOptMap.end()) ||
       (type == DOUBLE  && _dblOptMap.find(name) != _dblOptMap.end())) {
        return -1;
    }

    // add the option
    switch(type) {
    case(STRING):
        _strOptMap[name] = "";
        break;
    case(INTEGER):
        _intOptMap[name] = 0;
        break;
    case(DOUBLE):
        _dblOptMap[name] = 0.0;
        break;
    case(FUNCTION):
        _fnOptMap[name] = NULL;
        break;
    default:
        break;
    }
    _shortArgMap[shortArg] = name;
    _longArgMap[longArg] = name;

    return 0;
}

int
Config::_addOption(const std::string &longArg,
                   const std::string &name,
                   int type)
{
    // make sure we have a valid type
    if(type != STRING && type != INTEGER && type != DOUBLE) {
        return -1;
    }

    // check if the option already exists
    if(_longArgMap.find(longArg) != _longArgMap.end() ||
       (type == STRING  && _strOptMap.find(name) != _strOptMap.end()) ||
       (type == INTEGER && _intOptMap.find(name) != _intOptMap.end()) ||
       (type == DOUBLE  && _dblOptMap.find(name) != _dblOptMap.end())) {
        return -1;
    }

    // add the option
    switch(type) {
    case(STRING):
        _strOptMap[name] = "";
        break;
    case(INTEGER):
        _intOptMap[name] = 0;
        break;
    case(DOUBLE):
        _dblOptMap[name] = 0.0;
        break;
    default:
        break;
    }
    _longArgMap[longArg] = name;

    return 0;
}


/**
 * Add a given option and sets its default value.  The option is
 * specified as a short command line (-f), long command line (--foo),
 * option name (Foo), its type (integer or string), and its default
 * value.
 */
int
Config::addOption(char shortArg,
                  const std::string &longArg,
                  const std::string &name,
                  int defaultValue)
{
    int error;

    // add the option to the config system
    error = _addOption(shortArg, longArg, name, INTEGER);
    if(error) {
        return error;
    }

    // set the option to the default value
    error = setOption(name, defaultValue);
    if(error) {
        return error;
    }

    return 0;
}

/**
 * Add a given option and sets its default value.  The option is
 * specified as a short command line (-f), long command line (--foo),
 * option name (Foo), its type (integer or string), and its default
 * value.
 */
int
Config::addOption(char shortArg,
                  const std::string &longArg,
                  const std::string &name,
                  double defaultValue)
{
    int error;

    // add the option to the config system
    error = _addOption(shortArg, longArg, name, DOUBLE);
    if(error) {
        return error;
    }

    // set the option to the default value
    error = setOption(name, defaultValue);
    if(error) {
        return error;
    }

    return 0;
}


/**
 * Add a given option and sets its default value.  The option is
 * specified as a short command line (-f), long command line (--foo),
 * option name (Foo), its type (integer or string), and its default
 * value.
 */
int
Config::addOption(char shortArg,
                  const std::string &longArg,
                  const std::string &name,
                  const std::string &defaultValue)
{
    int error;

    // add the option to the config system
    error = _addOption(shortArg, longArg, name, STRING);
    if(error) {
        return error;
    }

    // set the option to the default value
    error = setOption(name, defaultValue);
    if(error) {
        return error;
    }

    return 0;
}

int
Config::addOption(char shortArg,
                  const std::string &longArg,
                  const std::string &name,
                  void (*defaultFn)(const std::string &))
{
    int error;

    // add the option to the config system
    error = _addOption(shortArg, longArg, name, FUNCTION);
    if(error) {
        return error;
    }

    // set the option to the default value
    error = setOption(name, defaultFn);
    if(error) {
        return error;
    }

    return 0;
}

int
Config::addOption(const std::string &longArg,
                  const std::string &name,
                  const std::string &defaultValue)
{
    int error;

    // add the option to the config system
    error = _addOption(longArg, name, STRING);
    if(error) {
        return error;
    }

    // set the option to the default value
    error = setOption(name, defaultValue);
    if(error) {
        return error;
    }

    return 0;
}

int
Config::addOption(const std::string &longArg,
                  const std::string &name,
                  int defaultValue)
{
    int error;

    // add the option to the config system
    error = _addOption(longArg, name, INTEGER);
    if(error) {
        return error;
    }

    // set the option to the default value
    error = setOption(name, defaultValue);
    if(error) {
        return error;
    }

    return 0;
}

int
Config::addOption(const std::string &longArg,
                  const std::string &name,
                  double defaultValue)
{
    int error;

    // add the option to the config system
    error = _addOption(longArg, name, DOUBLE);
    if(error) {
        return error;
    }

    // set the option to the default value
    error = setOption(name, defaultValue);
    if(error) {
        return error;
    }

    return 0;
}

int
Config::addOption(const std::string &name,
                  const std::string &defaultValue)
{
    if(_strOptMap.find(name) != _strOptMap.end()) {
        return -1;
    }

    // add the option
    _strOptMap[name] = defaultValue;
    return 0;
}

int
Config::addOption(const std::string &name,
                  int defaultValue)
{
    if(_intOptMap.find(name) != _intOptMap.end()) {
        return -1;
    }

    // add the option
    _intOptMap[name] = defaultValue;
    return 0;
}

int
Config::addOption(const std::string &name,
                  double defaultValue)
{
    if(_dblOptMap.find(name) != _dblOptMap.end()) {
        return -1;
    }

    // add the option
    _dblOptMap[name] = defaultValue;
    return 0;
}

/**
 * Sets the specified option to the given integer value.
 */
int
Config::setOption(const std::string &name,
                  int value)
{
    std::map<std::string, int>::iterator opt_i;

    // confirm that the option exists
    opt_i = _intOptMap.find(name);
    if(opt_i == _intOptMap.end()) {
        return -1;
    }

    // set the option
    opt_i->second = value;
    return 0;
}

/**
 * Sets the specified option to the given integer value.
 */
int
Config::setOption(const std::string &name,
                  double value)
{
    std::map<std::string, double>::iterator opt_i;

    // confirm that the option exists
    opt_i = _dblOptMap.find(name);
    if(opt_i == _dblOptMap.end()) {
        return -1;
    }

    // set the option
    opt_i->second = value;
    return 0;
}

/**
 * Sets the specified option to the given string value.
 */
int
Config::setOption(const std::string &name,
                  const std::string &value)
{
    std::map<std::string, std::string>::iterator opt_i;

    // confirm that the option exists
    opt_i = _strOptMap.find(name);
    if(opt_i == _strOptMap.end()) {
        return -1;
    }

    // set the option
    opt_i->second = value;
    return 0;
}

/**
 * Sets the specified option to the given function.
 */
int
Config::setOption(const std::string &name,
                  void (*value)(const std::string &))
{
    std::map<std::string, void (*)(const std::string &)>::iterator opt_i;

    // confirm that the option exists
    opt_i = _fnOptMap.find(name);
    if(opt_i == _fnOptMap.end()) {
        return -1;
    }

    // set the option
    opt_i->second = value;
    return 0;
}


int
Config::getOption(const std::string &name,
                  std::string *value) const
{
    std::map<std::string, std::string>::const_iterator opt_i;

    // confirm that the option exists
    opt_i = _strOptMap.find(name);
    if(opt_i == _strOptMap.end()) {
        return -1;
    }

    // get the option
    (*value) = opt_i->second;
    return 0;
}

int
Config::getOption(const std::string &name,
                  const char **value) const
{
    std::map<std::string, std::string>::const_iterator opt_i;

    // confirm that the option exists
    opt_i = _strOptMap.find(name);
    if(opt_i == _strOptMap.end()) {
        return -1;
    }

    // get the option
    (*value) = opt_i->second.c_str();
    return 0;
}

int
Config::getOption(const std::string &name,
                  int *value) const
{
    std::map<std::string, int>::const_iterator opt_i;

    // confirm that the option exists
    opt_i = _intOptMap.find(name);
    if(opt_i == _intOptMap.end()) {
        return -1;
    }

    // get the option
    (*value) = opt_i->second;
    return 0;
}

int
Config::getOption(const std::string &name,
                  double *value) const
{
    std::map<std::string, double>::const_iterator opt_i;

    // confirm that the option exists
    opt_i = _dblOptMap.find(name);
    if(opt_i == _dblOptMap.end()) {
        return -1;
    }

    // get the option
    (*value) = opt_i->second;
    return 0;
}

/**
 * Parses the command line arguments.  Short args are of the form -f
 * <opt>, long args are of the form --foo <opt>.  Returns < 0 on error,
 * or the index of the rom file in argv.
 */
int
Config::_parseArgs(int argc,
                   char **argv)
{
    int retval = 0;
    std::map<std::string, std::string>::iterator long_i, str_i;
    std::map<char, std::string>::iterator short_i;
    std::map<std::string, int>::iterator int_i;
    std::map<std::string, double>::iterator dbl_i;
    std::map<std::string, void (*)(const std::string &)>::iterator fn_i;
    std::string arg, opt, value;

    for(int i = 1; i < argc; i++) {
        arg = argv[i];
        if(arg[0] != '-') {
            // must be a rom name?
            retval = i;
            continue;
        }

        if(arg.size() < 2) {
            // XXX invalid argument
            return -1;
        }

        // parse the argument and get the option name
        if(arg[1] == '-') {
            // long arg
            long_i = _longArgMap.find(arg.substr(2));
            if(long_i == _longArgMap.end()) {
                // XXX invalid argument
                return -1;
            }

            opt = long_i->second;
        } else {
            // short arg
            short_i = _shortArgMap.find(arg[1]);
            if(short_i == _shortArgMap.end()) {
                // XXX invalid argument
                return -1;
            }

            opt = short_i->second;
        }

        // make sure we've got a value
        if(i + 1 >= argc) {
            // XXX missing value
            return -1;
        }
        i++;

        // now, find the appropriate option entry, and update it
        str_i = _strOptMap.find(opt);
        int_i = _intOptMap.find(opt);
        dbl_i = _dblOptMap.find(opt);
        fn_i  = _fnOptMap.find(opt);
        if(str_i != _strOptMap.end()) {
            str_i->second = argv[i];
        } else if(int_i != _intOptMap.end()) {
            int_i->second = atol(argv[i]);
        } else if(dbl_i != _dblOptMap.end()) {
            dbl_i->second = atof(argv[i]);
        } else if(fn_i != _fnOptMap.end()) {
            (*(fn_i->second))(argv[i]);
        } else {
            // XXX invalid option?  shouldn't happen
            return -1;
        }
    }

    // if we didn't get a rom-name, return error
    return (retval) ? retval : -1;
}


/**
 * Parses first the configuration file, and then overrides with any
 * command-line options that were specified.
 */
int
Config::parse(int argc,
              char **argv)
{
    int error;

    // read the config file
    error = _load();
    if(error) {
        return error;
    }

	// try to read cfg.d/*
	std::string cfgd_dir_name = _dir + "/" + "cfg.d/";
	DIR *d;
	struct dirent *dir;
	d = opendir(cfgd_dir_name.c_str());
	if (d)
	{
		while ((dir = readdir(d)) != NULL)
		{
			// dont load "." or ".."
			if(strcmp(dir->d_name, ".") == 0 || strcmp(dir->d_name, "..") == 0)
			{
				continue;
			}
						
			// TODO  0 = good -1 = bad
			std::string fname = cfgd_dir_name + dir->d_name;
			printf("Loading auxilary configuration file at %s...\n", fname.c_str());
			if (_loadFile(fname.c_str()) != 0)
			{
				printf("Failed to parse configuration at %s\n", fname.c_str());
			}
		}

		closedir(d);
	}

    // parse the arguments
    return _parseArgs(argc, argv);
}


/**
 * Read each line of the config file and put the variables into the
 * config maps.  Valid configuration lines are of the form:
 *
 * <option name> = <option value>
 *
 * Lines beginning with # are ignored.
 */
char* Config::getConfigDirectory()
{
	return strdup(_dir.c_str());
}

// load and parse the default configuration file
int
Config::_load()
{
	std::string configFile = _dir + "/" + cfgFile;
	bool success = Config::_loadFile(configFile.c_str())!=0;

	return success;
}	

// load and parse a given configuration file
int
Config::_loadFile(const char* fname)
{
	signed int pos, eqPos;
	std::fstream config;
	std::map<std::string, int>::iterator int_i;
	std::map<std::string, double>::iterator dbl_i;
	std::map<std::string, std::string>::iterator str_i;
	std::string configFile;
	// if no filename argument was passed, parse the default configuration file
	if(fname == NULL)
	{
		configFile = _dir + "/" + cfgFile;
	} else
	{
		configFile = fname;
	}
	std::string line, name, value;
	char buf[1024];

	// set the exception handling to catch i/o errors
	config.exceptions(std::fstream::badbit);

	try {
		// open the file for reading (create if it doesn't exist)
		config.open(configFile.c_str(), std::ios::in | std::ios::out);
		if(!config.is_open()) {
			// XXX file couldn't be opened?
			return 0;
			}

		while(!config.eof()) {
			// read a line
			config.getline(buf, 1024);
			line = buf;

			// check line validity
			eqPos = line.find("=");
			if(line[0] == '#') {
				// skip this line
				continue;
			}

			// get the name and value for the option
			pos = line.find(" ");
			name = line.substr(0, (pos > eqPos) ? eqPos : pos);
			pos = line.find_first_not_of(" ", eqPos + 1);
			if (pos == std::string::npos)
				value = "";
			else value = line.substr(pos);

			// check if the option exists, and if so, set it appropriately
			str_i = _strOptMap.find(name);
			dbl_i = _dblOptMap.find(name);
			int_i = _intOptMap.find(name);
			if(str_i != _strOptMap.end()) {
				str_i->second = value;
			} else if(int_i != _intOptMap.end()) {
				int_i->second = atol(value.c_str());
			} else if(dbl_i != _dblOptMap.end()) {
				dbl_i->second = atof(value.c_str());
			}
		}

		// close the file
		config.close();
	} catch(std::fstream::failure e) {
		std::cerr << e.what() << std::endl;
		return -1;
	}

	return 0;
}

/**
 * Writes the configuration file with the current configuration settings.
 */
int
Config::save()
{
	std::fstream config;
	std::map<std::string, int>::iterator int_i;
	std::map<std::string, double>::iterator dbl_i;
	std::map<std::string, std::string>::iterator str_i;
	std::string configFile = _dir + "/" + cfgFile;
	char buf[1024];

	// set the exception handling to catch i/o errors
	config.exceptions(std::ios::failbit | std::ios::badbit);

	try
	{
		// open the file, truncate and for write
		config.open(configFile.c_str(), std::ios::out | std::ios::trunc);

		// write a warning
		strcpy(buf, "# Auto-generated\n# SDL keysyms defined in /usr/include/SDL/SDL_keysym.h\n# getSDLKey can be found \
            in the source directory and can assist in remapping hotkeys\n#\n");
		config.write(buf, strlen(buf));

		// write each configuration setting
		for(int_i = _intOptMap.begin(); int_i != _intOptMap.end(); int_i++) 
		{
			snprintf(buf, 1024, "%s = %d\n",
				int_i->first.c_str(), int_i->second);
			config.write(buf, strlen(buf));
		}
		for(dbl_i = _dblOptMap.begin(); dbl_i != _dblOptMap.end(); dbl_i++) 
		{
			snprintf(buf, 1024, "%s = %f\n",
				dbl_i->first.c_str(), dbl_i->second);
			config.write(buf, strlen(buf));
		}
		for(str_i = _strOptMap.begin(); str_i != _strOptMap.end(); str_i++) 
		{
			snprintf(buf, 1024, "%s = %s\n",
				str_i->first.c_str(), str_i->second.c_str());
			config.write(buf, strlen(buf));
		}

		// close the file
		config.close();
	} catch(std::fstream::failure e)
	{
		std::cerr << e.what() << std::endl;
		return -1;
	}

	return 0;
}
