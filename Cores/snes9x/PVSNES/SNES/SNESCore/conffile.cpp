/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#include <stdio.h>
#include <time.h>
#include <string.h>
#include <string>

#include "conffile.h"

#ifdef __WIN32__
#define snprintf _snprintf // needs ANSI compliant name
#endif

#define SORT_SECTIONS_BY_SIZE // output

using namespace std;

bool ConfigFile::defaultAutoAdd = false;
bool ConfigFile::niceAlignment = false;
bool ConfigFile::showComments = true;
bool ConfigFile::alphaSort = true;
bool ConfigFile::timeSort = false;
static ConfigFile* curConfigFile = NULL; // for section_then_key_less

ConfigFile::ConfigFile(void) {
	Clear();
}

void ConfigFile::Clear(void){
    data.clear();
	sectionSizes.ClearSections();
	linectr = 0;
}

bool ConfigFile::LoadFile(const char *filename){
    FSTREAM s;
    bool ret=false;
    const char *n, *n2;

    if((s=OPEN_FSTREAM(filename, "r"))){
        n=filename;
        n2=strrchr(n, '/'); if(n2!=NULL) n=n2+1;
        n2=strrchr(n, '\\'); if(n2!=NULL) n=n2+1;
		fStream fS(s);
        LoadFile(&fS, n);
        CLOSE_FSTREAM(s);
        ret = true;
    } else {
        fprintf(stderr, "Couldn't open conffile ");
        perror(filename);
    }
    return ret;
}


void ConfigFile::LoadFile(Stream *r, const char *name){
	curConfigFile = this;
    string l, key, val;
    string section;
    string comment;
    int i, line, line2;
    bool eof;

    line=line2=0;
    section.clear();
    do {
        line=line2++;
        l=r->getline(eof);
        ConfigEntry::trim(l);
        if(l.size()==0) continue;

        if(l[0]=='#' || l[0]==';'){
            // comment
            continue;
        }

        if(l[0]=='['){
            if(*l.rbegin()!=']'){
                if(name) fprintf(stderr, "%s:", name);
                fprintf(stderr, "[%d]: Ignoring invalid section header\n", line);
                continue;
            }
            section.assign(l, 1, l.size()-2);
            continue;
        }

        while(*l.rbegin()=='\\'){
            l.erase(l.size()-1);
            line2++;
            val=r->getline(eof);
            if(eof){
                fprintf(stderr, "Unexpected EOF reading config file");
                if(name) fprintf(stderr, " '%s'", name);
                fprintf(stderr, "\n");
                return;
            }
            ConfigEntry::trim(val);
            l+=val;
        }
        i=l.find('=');
        if(i<0){
            if(name) fprintf(stderr, "%s:", name);
            fprintf(stderr, "[%d]: Ignoring invalid entry\n", line);
            continue;
        }
        key=l.substr(0,i); ConfigEntry::trim(key);
		val=l.substr(i+1); comment = ConfigEntry::trimCommented(val);
		if(val.size() > 0 && val[0]=='"' && *val.rbegin()=='"') val=val.substr(1, val.size()-2);

        ConfigEntry e(line, section, key, val);
		e.comment = comment;
        if(data.erase(e))
			sectionSizes.DecreaseSectionSize(e.section);
        data.insert(e);
		sectionSizes.IncreaseSectionSize(e.section);
    } while(!eof);
	curConfigFile = NULL;
}

bool ConfigFile::SaveTo(const char *filename){
    string section;
    FILE *fp;

    if((fp=fopen(filename, "w"))==NULL){
        fprintf(stderr, "Couldn't write conffile ");
        perror(filename);
        return false;
    }

	curConfigFile = this;
    section.clear();
    set<ConfigEntry, ConfigEntry::line_less> tmp;
    fprintf(fp, "# Config file output by snes9x\n");
    time_t t=time(NULL);
    fprintf(fp, "# %s", ctime(&t));

#ifdef SORT_SECTIONS_BY_SIZE
	std::set<ConfigEntry, ConfigEntry::section_then_key_less> data2;
	for(set<ConfigEntry, ConfigEntry::key_less>::iterator k=data.begin(); k!=data.end(); k++){
		ConfigEntry e (k->line, k->section, k->key, k->val); e.comment = k->comment;
		data2.insert(e);
	}
#else
	#define data2 data
	#define section_then_key_less key_less
#endif

    for(set<ConfigEntry, ConfigEntry::section_then_key_less>::iterator j=data2.begin(); ; j++){
        if(j==data2.end() || j->section!=section){
            if(!tmp.empty()){
                fprintf(fp, "\n[%s]\n", section.c_str());
				unsigned int maxKeyLen=0, maxValLen=0; int maxLeftDiv=0; int maxRightDiv=-1;
				if(niceAlignment){
					for(set<ConfigEntry, ConfigEntry::line_less>::iterator i=tmp.begin(); i!=tmp.end(); i++){
						int len3 = i->key.find_last_of(':');
						maxRightDiv = MAX(maxRightDiv, len3);
						len3 = i->key.length() - len3;
						maxLeftDiv = MAX(maxLeftDiv, len3);
						maxKeyLen = MAX(maxKeyLen, i->key.length()+3);
						if(showComments){
							string o=i->val; ConfigEntry::trim(o);
							unsigned int len = o.length();
							for(signed int j=len-1;j>=0;j--) if(o.at(j)=='#') len++;
							if(o!=i->val) len+=2;
							maxValLen = MAX(maxValLen, len);
						}
					}
					if(maxValLen>48) maxValLen=48; // limit spacing
				}

				for(set<ConfigEntry, ConfigEntry::line_less>::iterator i=tmp.begin(); i!=tmp.end(); i++){
                    string o=i->val; ConfigEntry::trim(o);
                    if(o!=i->val) o="\""+i->val+"\"";
					int off=0, len3=0;
					for(;;){
						int k=o.find('#',off);
						if(k>=0){
							o.insert(k,1,'#'); // re-double any comment characters
							off=k+2;
							if(off<(int)o.length()) continue;
						}
						break;
					}
					if(niceAlignment){
						len3=i->key.find_last_of(':');
						int len3sub=0;
						if(len3 < maxRightDiv){
							for(int j=len3;j<maxRightDiv;j++) fputc(' ',fp);
							len3sub=maxRightDiv-len3;
							len3 = maxRightDiv;
						}
						len3+=maxLeftDiv-i->key.length();
						for(unsigned int j=i->key.length()+len3+3;j<maxKeyLen;j++) fputc(' ',fp);
						fprintf(fp, "%s", i->key.c_str());
						for(int j=0;j<len3-len3sub;j++) fputc(' ',fp);
						fprintf(fp, " = %s", o.c_str());
					} else
						fprintf(fp, "%s = %s", i->key.c_str(), o.c_str());

					if(showComments && !i->comment.empty()){
						if(niceAlignment) for(unsigned int j=o.length();j<maxValLen;j++) fputc(' ',fp);
						fprintf(fp, "  # %s", i->comment.c_str());
					}
					fprintf(fp, "\n");
                }
            }
            if(j==data2.end()) break;
            section=j->section;
            tmp.clear();
        }
        tmp.insert(*j);
    }
	curConfigFile = NULL;

	#undef data2
	#undef section_then_key_less

	if(ferror(fp))
	{
		printf ("Error writing config file %s\n", filename);
	}

    fclose(fp);
    return true;
}


/***********************************************/

string ConfigFile::Get(const char *key){
	set<ConfigEntry, ConfigEntry::key_less>::iterator i;
    i=data.find(ConfigEntry(key));
	i->used=true;
    return i->val;
}
bool ConfigFile::Has(const char *key){
    return data.find(ConfigEntry(key))!=data.end();
}

// exists and isn't completely empty (any side-effects are intentional)
bool ConfigFile::Exists(const char *key){
	const char* val = GetString(key, NULL);
	return val && *val;
}


string ConfigFile::GetString(const char *key, string def){
    if(!Exists(key))
		return def;
    return Get(key);
}

char *ConfigFile::GetString(const char *key, char *out, uint32 outlen){
    if(!Exists(key)) return NULL;
    memset(out, 0, outlen);
    string o=Get(key);
    if(outlen>0){
        outlen--;
        if(o.size()<outlen) outlen=o.size();
        memcpy(out, o.data(), outlen);
    }
    return out;
}

const char *ConfigFile::GetString(const char *key, const char *def){
    set<ConfigEntry, ConfigEntry::key_less>::iterator i;
    i=data.find(ConfigEntry(key));
	if(i==data.end())
	{
		if(defaultAutoAdd) SetString(key,""); //SetString(key, def?def:"");
		return def;
	}
	i->used=true;
    // This should be OK, until this key gets removed
	const std::string &iVal = i->val;
	return iVal.c_str();
}

char *ConfigFile::GetStringDup(const char *key, const char *def){
    const char *c=GetString(key, def);
    if(c==NULL) return NULL;
    return strdup(c);
}

bool ConfigFile::SetString(const char *key, string val, const char *comment){
    set<ConfigEntry, ConfigEntry::key_less>::iterator i;
    bool ret=false;
    bool found;

    ConfigEntry e(key, val);
	if(comment && *comment) e.comment = comment;
	e.used=true;

    i=data.find(e);
    found=(i==data.end());
    if(!found){
        e.line=i->line;
        data.erase(e);
		sectionSizes.DecreaseSectionSize(e.section);
        ret=true;
    }
	if((found && (!alphaSort || timeSort)) || (!alphaSort && timeSort))
		e.line = linectr++;

    data.insert(e);
	sectionSizes.IncreaseSectionSize(e.section);
    return ret;
}

int32 ConfigFile::GetInt(const char *key, int32 def, bool *bad){
    if(bad) *bad=false;
	if(!Exists(key))
		return def;
    char *c;
    int32 i;
    string o=Get(key);
    i=strtol(o.c_str(), &c, 10);
    if(c!=NULL && *c!='\0'){
        i=def;
        if(bad) *bad=true;
    }
    return i;
}

bool ConfigFile::SetInt(const char *key, int32 val, const char *comment){
    char buf[20];
    snprintf(buf, sizeof(buf), "%d", (int)val);
    return SetString(key, buf, comment);
}

uint32 ConfigFile::GetUInt(const char *key, uint32 def, int base, bool *bad){
    if(bad) *bad=false;
	if(!Exists(key))
		return def;
    if(base!=8 && base!=10 && base!=16) base=0;
    char *c;
    uint32 i;
    string o=Get(key);
    i=strtol(o.c_str(), &c, base);
    if(c!=NULL && *c!='\0'){
        i=def;
        if(bad) *bad=true;
    }
    return i;
}

bool ConfigFile::SetUInt(const char *key, uint32 val, int base, const char *comment){
    char buf[20];
    switch(base){
      case 10:
      default:
        snprintf(buf, sizeof(buf), "%u", (unsigned int)val);
        break;
      case 8:
        snprintf(buf, sizeof(buf), "%#o", (unsigned int)val);
        break;
      case 16:
        snprintf(buf, sizeof(buf), "%#x", (unsigned int)val);
        break;
    }
    return SetString(key, buf, comment);
}

bool ConfigFile::GetBool(const char *key, bool def, bool *bad){
    if(bad) *bad=false;
    if(!Exists(key))
		return def;
    string o=Get(key);
    const char *c=o.c_str();
    if(!strcasecmp(c, "true") || !strcasecmp(c, "1") || !strcasecmp(c, "yes") || !strcasecmp(c, "on")) return true;
    if(!strcasecmp(c, "false") || !strcasecmp(c, "0") || !strcasecmp(c, "no") || !strcasecmp(c, "off")) return false;
    if(bad) *bad=true;
    return def;
}

bool ConfigFile::SetBool(const char *key, bool val, const char *true_val, const char *false_val, const char *comment){
    return SetString(key, val?true_val:false_val, comment);
}

const char* ConfigFile::GetComment(const char *key)
{
    set<ConfigEntry, ConfigEntry::key_less>::iterator i;
    i=data.find(ConfigEntry(key));
	if(i==data.end())
		return NULL;

    // This should be OK, until this key gets removed
	const std::string &iCom = i->comment;
	return iCom.c_str();
}

bool ConfigFile::DeleteKey(const char *key){
	ConfigEntry e = ConfigEntry(key);
	if(data.erase(e)) {
		sectionSizes.DecreaseSectionSize(e.section);
		return true;
	}
    return false;
}

/***********************************************/

bool ConfigFile::DeleteSection(const char *section){
    set<ConfigEntry, ConfigEntry::key_less>::iterator s, e;

    for(s=data.begin(); s!=data.end() && s->section!=section; s++) ;
    if(s==data.end()) return false;
    for(e=s; e!=data.end() && e->section==section; e++) ;
    data.erase(s, e);
	sectionSizes.DeleteSection(section);
    return true;
}

ConfigFile::secvec_t ConfigFile::GetSection(const char *section){
    secvec_t v;
    set<ConfigEntry, ConfigEntry::key_less>::iterator i;

    v.clear();
    for(i=data.begin(); i!=data.end(); i++){
        if(i->section!=section) continue;
        v.push_back(std::pair<string,string>(i->key, i->val));
    }
    return v;
}

int ConfigFile::GetSectionSize(const std::string section){
	return sectionSizes.GetSectionSize(section);
}

// Clears all key-value pairs that didn't receive a "Get" or "Exists" command
void ConfigFile::ClearUnused()
{
    set<ConfigEntry, ConfigEntry::key_less>::iterator i;
again:
    for(i=data.begin(); i!=data.end(); i++){
		if(!i->used){
			data.erase(i);
			goto again;
		}
	}
}

void ConfigFile::ClearLines()
{
    set<ConfigEntry, ConfigEntry::key_less>::iterator i;
    for(i=data.begin(); i!=data.end(); i++){
		*(const_cast<int*>(&i->line)) = -1;
    }
}

bool ConfigFile::ConfigEntry::section_then_key_less::operator()(const ConfigEntry &a, const ConfigEntry &b) {
	if(curConfigFile && a.section!=b.section){
		const int sva = curConfigFile->GetSectionSize(a.section);
		const int svb = curConfigFile->GetSectionSize(b.section);
		if(sva<svb) return true;
		if(sva>svb) return false;
		return a.section<b.section;
	}
	return a.key<b.key;
}


void ConfigFile::SetDefaultAutoAdd(bool autoAdd)
{
	defaultAutoAdd = autoAdd;
}
void ConfigFile::SetNiceAlignment(bool align)
{
	niceAlignment = align;
}
void ConfigFile::SetShowComments(bool show)
{
	showComments = show;
}
void ConfigFile::SetAlphaSort(bool sort)
{
	alphaSort = sort;
}
void ConfigFile::SetTimeSort(bool sort)
{
	timeSort = sort;
}
