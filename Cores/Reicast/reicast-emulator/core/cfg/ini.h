#pragma once
#include "types.h"
#include <map>

struct ConfigEntry {
	string value;
	string get_string();
	int get_int();
	bool get_bool();
};

struct ConfigSection {
	std::map<string, ConfigEntry> entries;
	bool has_entry(string name);
	void set(string name, string value);
	ConfigEntry* get_entry(string name);
};

struct ConfigFile {
	private:
		std::map<string, ConfigSection> sections;
		std::map<string, ConfigSection> virtual_sections;
		ConfigSection* add_section(string name, bool is_virtual);
		ConfigSection* get_section(string name, bool is_virtual);
		ConfigEntry* get_entry(string section_name, string entry_name);


	public:
		bool has_section(string name);
		bool has_entry(string section_name, string entry_name);

		void parse(FILE* fd);
		void save(FILE* fd);

		/* getting values */
		string get(string section_name, string entry_name, string default_value = "");
		int get_int(string section_name, string entry_name, int default_value = 0);
		bool get_bool(string section_name, string entry_name, bool default_value = false);
		/* setting values */
		void set(string section_name, string entry_name, string value, bool is_virtual = false);
		void set_int(string section_name, string entry_name, int value, bool is_virtual = false);
		void set_bool(string section_name, string entry_name, bool value, bool is_virtual = false);
};
