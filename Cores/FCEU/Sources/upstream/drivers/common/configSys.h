#ifndef __CONFIGSYS_H
#define __CONFIGSYS_H

#include <map>
#include <string>

class Config {
private:
    std::string _dir;

    std::map<std::string, std::string>    _strOptMap;
    std::map<std::string, int>            _intOptMap;
    std::map<std::string, double>         _dblOptMap;
    std::map<std::string, void (*)(const std::string &)> _fnOptMap;

    std::map<char, std::string>        _shortArgMap;
    std::map<std::string, std::string> _longArgMap;

private:
    int _addOption(char, const std::string &, const std::string &, int);
    int _addOption(const std::string &, const std::string &, int);
    int _load(void);
	int _loadFile(const char* fname);
    int _parseArgs(int, char **);

public:
    const static int STRING   = 1;
    const static int INTEGER  = 2;
    const static int DOUBLE   = 3;
    const static int FUNCTION = 4;

public:
    Config(std::string d) : _dir(d) { }
    ~Config() { }

    /**
     * Adds a configuration option.  All options must be added before
     * parse().
     */
    int addOption(char, const std::string &,
                  const std::string &, const std::string &);
    int addOption(char, const std::string &,
                  const std::string &, int);
    int addOption(char, const std::string &,
                  const std::string &, double);
    int addOption(char, const std::string &,
                  const std::string &, void (*)(const std::string &));

    int addOption(const std::string &,
                  const std::string &, const std::string &);
    int addOption(const std::string &, const std::string &, int);
    int addOption(const std::string &, const std::string &, double);
    //int addOption(const std::string &,
    //              const std::string &, void (*)(const std::string &));

    int addOption(const std::string &, const std::string &);
    int addOption(const std::string &, int);
    int addOption(const std::string &, double);
    //int addOption(const std::string &, void (*)(const std::string &));

    /**
     * Sets a configuration option.  Can be called at any time.
     */
    int setOption(const std::string &, const std::string &);
    int setOption(const std::string &, int);
    int setOption(const std::string &, double);
    int setOption(const std::string &, void (*)(const std::string &));

    int getOption(const std::string &, std::string *) const;
    int getOption(const std::string &, const char **) const;
    int getOption(const std::string &, int *) const;
    int getOption(const std::string &, double *) const;

    /**
     * Parse the arguments.  Also read in the configuration file and
     * set the variables accordingly.
     */
    int parse(int, char **);
    
    /**
     * Returns the directory of the configuration files.
     *
     */
    
    char* getConfigDirectory();

    /**
     * Save all of the current configuration options to the
     * configuration file.
     */
    int save();
};

#endif // !__CONFIGSYS_H
