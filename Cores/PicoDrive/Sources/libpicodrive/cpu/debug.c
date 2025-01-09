/*
 * PDB, the PicoDrive debugger
 * (C) notaz, 2010
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
#define _GNU_SOURCE
#include <stdio.h>

#include "../pico/pico_int.h"
#include "debug.h"

static char pdb_pending_cmds[128];
static char pdb_event_cmds[128];

static struct pdb_cpu {
  void *context;
  int type;
  int id;
  const char *name;
  unsigned int bpts[16];
  int bpt_count;
  int icount;
} pdb_cpus[5];
static int pdb_cpu_count;

static int pdb_global_icount;

#ifdef PDB_NET
#include <stddef.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>

#include "debug_net.h"

static int pdb_net_sock = -1;

int pdb_net_connect(const char *host, const char *port)
{
  struct sockaddr_in sockadr;
  int sock = -1;
  int ret;

  sock = socket(PF_INET, SOCK_STREAM, 0);
  if (sock == -1) {
    perror("socket");
    return -1;
  }

  sockadr.sin_addr.s_addr = inet_addr(host);
  sockadr.sin_family = AF_INET;
  sockadr.sin_port = htons(atoi(port));

  ret = connect(sock, (struct sockaddr *)&sockadr, sizeof(sockadr));
  if (ret != 0) {
    perror("pdb_net: connect");
    close(sock);
    return -1;
  }

  printf("pdb_net: connected to %s:%s\n", host, port);

  pdb_net_sock = sock;
  return 0;
}

static int pdb_net_send(struct pdb_cpu *cpu, unsigned int pc)
{
  packet_t packet;
  int ret;

  if (pdb_net_sock < 0)
    return 0; // not connected

  if (cpu->type == PDBCT_SH2) {
    SH2 *sh2 = cpu->context;
    int rl = offsetof(SH2, macl) + sizeof(sh2->macl);
    packet.header.type = PDBCT_SH2;
    packet.header.cpuid = cpu->id;
    packet.regs[0] = pc;
    memcpy(&packet.regs[1], sh2->r, rl);
    packet.regs[1+24+0] = sh2->pdb_io_csum[0];
    packet.regs[1+24+1] = sh2->pdb_io_csum[1];
    packet.header.len = 4 + rl + 4*2;
    sh2->pdb_io_csum[0] = sh2->pdb_io_csum[1] = 0;
  }
  else
    memset(&packet, 0, sizeof(packet));

  ret = send(pdb_net_sock, &packet, sizeof(packet.header) + packet.header.len, MSG_NOSIGNAL);
  if (ret != sizeof(packet.header) + packet.header.len) {
    if (ret < 0)
      perror("send");
    else
      printf("send: %d/%d\n", ret, sizeof(packet.header) + packet.header.len);
    close(pdb_net_sock);
    pdb_net_sock = -1;
    ret = -1;
  }
  return ret;
}
#else
#define pdb_net_send(a,b) 0
#endif // PDB_NET

#ifdef HAVE_READLINE
#include <readline/readline.h>
#include <readline/history.h>
#endif

static char *my_readline(const char *prompt)
{
  char *line = NULL;

#ifdef HAVE_READLINE
  line = readline("(pdb) ");
  if (line == NULL)
    return NULL;
  if (line[0] != 0)
    add_history(line);
#else
  size_t size = 0;
  ssize_t ret;

  printf("(pdb) ");
  fflush(stdout);
  ret = getline(&line, &size, stdin);
  if (ret < 0)
    return NULL;
  if (ret > 0 && line[ret - 1] == '\n')
    line[ret - 1] = 0;
#endif

  return line;
}

static struct pdb_cpu *context2cpu(const void *context)
{
  int i;
  for (i = 0; i < pdb_cpu_count; i++)
    if (pdb_cpus[i].context == context)
      return &pdb_cpus[i];
  return NULL;
}

static const char *get_token(char *buf, int blen, const char *str)
{
  const char *p, *s, *e;
  int len;

  p = str;
  while (isspace_(*p))
    p++;
  if (*p == 0)
    return NULL;
  if (*p == ';') {
    strcpy(buf, ";");
    return p + 1;
  }

  s = p;
  while (*p != 0 && *p != ';' && !isspace_(*p))
    p++;
  e = p;
  while (isspace_(*e))
    e++;

  len = p - s;
  if (len > blen - 1)
    len = blen - 1;
  memcpy(buf, s, len);
  buf[len] = 0;
  return e;
}

static const char *get_arg(char *buf, int blen, const char *str)
{
  if (*str == ';')
    return NULL;
  return get_token(buf, blen, str);
}

enum cmd_ret_e {
  CMDRET_DONE,          // ..and back to prompt
//  CMDRET_PROMPT,        // go to prompt
  CMDRET_CONT_DO_NEXT,  // continue and do remaining cmds on next event
  CMDRET_CONT_REDO,     // continue and redo all cmds on next event
};

static int do_print(struct pdb_cpu *cpu, const char *args)
{
  elprintf(EL_STATUS, "cpu %d (%s)", cpu->id, cpu->name);
#ifndef NO_32X
  if (cpu->type == PDBCT_SH2) {
    SH2 *sh2 = cpu->context;
    int i;
    printf("PC,SR %08x,     %03x\n", sh2->pc, sh2->sr & 0x3ff);
    for (i = 0; i < 16/2; i++)
      printf("R%d,%2d %08x,%08x\n", i, i + 8, sh2->r[i], sh2->r[i + 8]);
    printf("gb,vb %08x,%08x\n", sh2->gbr, sh2->vbr);
    printf("IRQs/mask:        %02x/%02x\n", Pico32x.sh2irqi[sh2->is_slave],
      Pico32x.sh2irq_mask[sh2->is_slave]);
    printf("cycles %d/%d (%d)\n", sh2->cycles_done, sh2->cycles_aim, (signed int)sh2->sr >> 12);
  }
#endif
  return CMDRET_DONE;
}

static int do_step_all(struct pdb_cpu *cpu, const char *args)
{
  char tmp[32];
  if (!get_arg(tmp, sizeof(tmp), args)) {
    printf("step_all: missing arg\n");
    return CMDRET_DONE;
  }

  pdb_global_icount = atoi(tmp);
  return CMDRET_CONT_DO_NEXT;
}

static int do_continue(struct pdb_cpu *cpu, const char *args)
{
  char tmp[32];
  if (get_arg(tmp, sizeof(tmp), args))
    cpu->icount = atoi(tmp);
  return CMDRET_CONT_DO_NEXT;
}

static int do_step(struct pdb_cpu *cpu, const char *args)
{
  cpu->icount = 1;
  return do_continue(cpu, args);
}

static int do_waitcpu(struct pdb_cpu *cpu, const char *args)
{
  char tmp[32];
  if (!get_arg(tmp, sizeof(tmp), args)) {
    printf("waitcpu: missing arg\n");
    return CMDRET_DONE;
  }
  if (strcmp(tmp, cpu->name) == 0)
    return CMDRET_DONE;

  return CMDRET_CONT_REDO;
}

static int do_help(struct pdb_cpu *cpu, const char *args);

static struct {
  const char *cmd;
  const char *help;
  int (*handler)(struct pdb_cpu *cpu, const char *args);
} pdb_cmds[] = {
  { "help",     "",          do_help },
  { "continue", "[insns]",   do_continue },
  { "step",     "[insns]",   do_step },
  { "step_all", "<insns>",   do_step_all },
  { "waitcpu",  "<cpuname>", do_waitcpu },
  { "print",    "",          do_print },
};

static int do_help(struct pdb_cpu *cpu, const char *args)
{
  int i;
  for (i = 0; i < ARRAY_SIZE(pdb_cmds); i++)
    printf("%s %s\n", pdb_cmds[i].cmd, pdb_cmds[i].help);
  return CMDRET_DONE;
}

static int do_comands(struct pdb_cpu *cpu, const char *cmds)
{
  const char *p = cmds;
  while (p != NULL)
  {
    const char *pcmd;
    char cmd[32];
    int i, len;
    int ret = 0;

    pcmd = p;
    p = get_token(cmd, sizeof(cmd), p);
    if (p == NULL)
      break;
    if (cmd[0] == ';')
      continue;

    len = strlen(cmd);
    for (i = 0; i < ARRAY_SIZE(pdb_cmds); i++)
      if (strncmp(pdb_cmds[i].cmd, cmd, len) == 0) {
        ret = pdb_cmds[i].handler(cpu, p);
        break;
      }

    if (i == ARRAY_SIZE(pdb_cmds)) {
      printf("bad cmd: %s\n", cmd);
      break;
    }

    // skip until next command
    while (1) {
      p = get_token(cmd, sizeof(cmd), p);
      if (p == NULL || cmd[0] == ';')
        break;
    }

    pdb_event_cmds[0] = 0;
    if (ret == CMDRET_CONT_DO_NEXT) {
      pdb_pending_cmds[0] = 0;
      if (p != NULL)
        strcpy(pdb_event_cmds, p);
      return 0;
    }
    if (ret == CMDRET_CONT_REDO) {
      if (pcmd != pdb_pending_cmds)
        strncpy(pdb_pending_cmds, pcmd, sizeof(pdb_pending_cmds));
      return 0;
    }
    pdb_pending_cmds[0] = 0;
  }

  return 1;
}

static void do_prompt(struct pdb_cpu *cpu)
{
  static char prev[128];
  int ret;

  while (1) {
    char *line, *cline;

    line = my_readline("(pdb) ");
    if (line == NULL)
      break;
    if (line[0] == 0)
      cline = prev;
    else {
      cline = line;
      strncpy(prev, line, sizeof(prev));
    }
      
    ret = do_comands(cpu, cline);
    free(line);

    if (ret == 0)
      break;
  }
}

void pdb_register_cpu(void *context, int type, const char *name)
{
  int i = pdb_cpu_count;
  memset(&pdb_cpus[i], 0, sizeof(pdb_cpus[i]));
  pdb_cpus[i].context = context;
  pdb_cpus[i].type = type;
  pdb_cpus[i].id = pdb_cpu_count;
  pdb_cpus[i].name = name;
  pdb_cpus[i].icount = -1;
  pdb_cpu_count++;
}

void pdb_step(void *context, unsigned int pc)
{
  struct pdb_cpu *cpu = context2cpu(context);
  int i;

  if (pdb_net_send(cpu, pc) < 0)
    goto prompt;

  if (pdb_pending_cmds[0] != 0)
    if (do_comands(cpu, pdb_pending_cmds))
      goto prompt;

  // breakpoint?
  for (i = 0; i < cpu->bpt_count; i++)
    if (cpu->bpts[i] == pc)
      goto prompt;

  // hit num of insns?
  if (pdb_global_icount > 0)
    if (--pdb_global_icount == 0)
      goto prompt;

  if (cpu->icount > 0)
    if (--(cpu->icount) == 0)
      goto prompt;

  return;

prompt:
  if (pdb_event_cmds[0] != 0)
    if (!do_comands(cpu, pdb_event_cmds))
      return;

  printf("%s @%08x\n", cpu->name, pc);
  do_prompt(cpu);
}

void pdb_command(const char *cmd)
{
  strncpy(pdb_pending_cmds, cmd, sizeof(pdb_pending_cmds));
  pdb_pending_cmds[sizeof(pdb_pending_cmds) - 1] = 0;
}

void pdb_cleanup(void)
{
  pdb_cpu_count = 0;
}

// vim:shiftwidth=2:expandtab
