
#ifdef PDB

enum {
  PDBCT_SH2,
};

void pdb_register_cpu(void *context, int type, const char *name);
void pdb_cleanup(void);
void pdb_step(void *context, unsigned int pc);
void pdb_command(const char *cmd);

#else

#define pdb_register_cpu(a,b,c)
#define pdb_cleanup()
#define pdb_step(a,b)
#define pdb_command(a)

#endif


#if defined(PDB) && defined(PDB_NET)

int pdb_net_connect(const char *host, const char *port);

#else

static inline int pdb_net_connect(const char *host, const char *port) {return 0;}

#endif
