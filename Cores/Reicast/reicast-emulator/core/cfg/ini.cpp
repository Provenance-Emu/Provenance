#include "ini.h"
#include <sstream>

wchar* trim_ws(wchar* str);

/* ConfigEntry */

string ConfigEntry::get_string()
{
	return this->value;
}

int ConfigEntry::get_int()
{
	if (strstr(this->value.c_str(), "0x") != NULL)
	{
		return strtol(this->value.c_str(), NULL, 16);
	}
	else
	{
		return atoi(this->value.c_str());
	}
}

bool ConfigEntry::get_bool()
{
	if (stricmp(this->value.c_str(), "yes") == 0 ||
		  stricmp(this->value.c_str(), "true") == 0 ||
		  stricmp(this->value.c_str(), "on") == 0 ||
		  stricmp(this->value.c_str(), "1") == 0)
	{
		return true;
	}
	else
	{
		return false;
	}
}

/* ConfigSection */

bool ConfigSection::has_entry(string name)
{
	return (this->entries.count(name) == 1);
};

ConfigEntry* ConfigSection::get_entry(string name)
{
	if(this->has_entry(name))
	{
		return &this->entries[name];
	}
	return NULL;
};

void ConfigSection::set(string name, string value)
{
	ConfigEntry new_entry = { value };
	this->entries[name] = new_entry;
};

/* ConfigFile */

ConfigSection* ConfigFile::add_section(string name, bool is_virtual)
{
	ConfigSection new_section;
	if (is_virtual)
	{
		this->virtual_sections.insert(std::make_pair(name, new_section));
		return &this->virtual_sections[name];
	}
	this->sections.insert(std::make_pair(name, new_section));
	return &this->sections[name];
};

bool ConfigFile::has_section(string name)
{
	return (this->virtual_sections.count(name) == 1 || this->sections.count(name) == 1);
}

bool ConfigFile::has_entry(string section_name, string entry_name)
{
	ConfigSection* section = this->get_section(section_name, true);
	if ((section != NULL) && section->has_entry(entry_name))
	{
		return true;
	}
	section = this->get_section(section_name, false);
	return ((section != NULL) && section->has_entry(entry_name));
}

ConfigSection* ConfigFile::get_section(string name, bool is_virtual)
{
	if(is_virtual)
	{
		if (this->virtual_sections.count(name) == 1)
		{
			return &this->virtual_sections[name];
		}
	}
	else
	{
		if (this->sections.count(name) == 1)
		{
			return &this->sections[name];
		}
	}
	return NULL;
};

ConfigEntry* ConfigFile::get_entry(string section_name, string entry_name)
{
	ConfigSection* section = this->get_section(section_name, true);
	if(section != NULL && section->has_entry(entry_name))
	{
		return section->get_entry(entry_name);
	}

		section = this->get_section(section_name, false);
	if(section != NULL)
	{
		return section->get_entry(entry_name);
	}
	return NULL;

}

string ConfigFile::get(string section_name, string entry_name, string default_value)
{
	ConfigEntry* entry = this->get_entry(section_name, entry_name);
	if (entry == NULL)
	{
		return default_value;
	}
	else
	{
		return entry->get_string();
	}
}

int ConfigFile::get_int(string section_name, string entry_name, int default_value)
{
	ConfigEntry* entry = this->get_entry(section_name, entry_name);
	if (entry == NULL)
	{
		return default_value;
	}
	else
	{
		return entry->get_int();
	}
}

bool ConfigFile::get_bool(string section_name, string entry_name, bool default_value)
{
	ConfigEntry* entry = this->get_entry(section_name, entry_name);
	if (entry == NULL)
	{
		return default_value;
	}
	else
	{
		return entry->get_bool();
	}
}

void ConfigFile::set(string section_name, string entry_name, string value, bool is_virtual)
{
	ConfigSection* section = this->get_section(section_name, is_virtual);
	if(section == NULL)
	{
		section = this->add_section(section_name, is_virtual);
	}
	section->set(entry_name, value);
};

void ConfigFile::set_int(string section_name, string entry_name, int value, bool is_virtual)
{
	std::stringstream str_value;
	str_value << value;
	this->set(section_name, entry_name, str_value.str(), is_virtual);
}

void ConfigFile::set_bool(string section_name, string entry_name, bool value, bool is_virtual)
{
	string str_value = (value ? "yes" : "no");
	this->set(section_name, entry_name, str_value, is_virtual);
}

void ConfigFile::parse(FILE* file)
{
	if(file == NULL)
	{
		return;
	}
	char line[512];
	char current_section[512] = { '\0' };
	int cline = 0;
	while(file && !feof(file))
	{
		if (fgets(line, 512, file) == NULL || feof(file))
		{
			break;
		}

		cline++;

		if (strlen(line) < 3)
		{
			continue;
		}

		if (line[strlen(line)-1] == '\r' ||
			  line[strlen(line)-1] == '\n')
		{
			line[strlen(line)-1] = '\0';
		}

		char* tl = trim_ws(line);

		if (tl[0] == '[' && tl[strlen(tl)-1] == ']')
		{
			tl[strlen(tl)-1] = '\0';

			// FIXME: Data loss if buffer is too small
			strncpy(current_section, tl+1, sizeof(current_section));
			current_section[sizeof(current_section) - 1] = '\0';

			trim_ws(current_section);
		}
		else
		{
			if (strlen(current_section) == 0)
			{
				continue; //no open section
			}

			char* separator = strstr(tl, "=");

			if (!separator)
			{
				printf("Malformed entry on config - ignoring @ %d(%s)\n",cline, tl);
				continue;
			}

			*separator = '\0';

			char* name = trim_ws(tl);
			char* value = trim_ws(separator + 1);
			if (name == NULL || value == NULL)
			{
				printf("Malformed entry on config - ignoring @ %d(%s)\n",cline, tl);
				continue;
			}
			else
			{
				this->set(string(current_section), string(name), string(value));
			}
		}
	}
}

void ConfigFile::save(FILE* file)
{
	for(std::map<string, ConfigSection>::iterator section_it = this->sections.begin();
		  section_it != this->sections.end(); section_it++)
	{
		string section_name = section_it->first;
		ConfigSection section = section_it->second;

		fprintf(file, "[%s]\n", section_name.c_str());

		for(std::map<string, ConfigEntry>::iterator entry_it = section.entries.begin();
			  entry_it != section.entries.end(); entry_it++)
		{
			string entry_name = entry_it->first;
			ConfigEntry entry = entry_it->second;
			fprintf(file, "%s = %s\n", entry_name.c_str(), entry.get_string().c_str());
		}

		fputs("\n", file);
	}
}
