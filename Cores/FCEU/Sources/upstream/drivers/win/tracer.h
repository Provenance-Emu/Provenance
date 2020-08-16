#define LOG_OPTION_SIZE 10

#define LOG_REGISTERS             1
#define LOG_PROCESSOR_STATUS      2
#define LOG_NEW_INSTRUCTIONS      4
#define LOG_NEW_DATA              8
#define LOG_TO_THE_LEFT          16
#define LOG_FRAMES_COUNT         32
#define LOG_MESSAGES             64
#define LOG_BREAKPOINTS         128
#define LOG_SYMBOLIC            256
#define LOG_CODE_TABBING        512
#define LOG_CYCLES_COUNT       1024
#define LOG_INSTRUCTIONS_COUNT 2048

#define LOG_LINE_MAX_LEN 160
// Frames count - 1+6+1 symbols
// Cycles count - 1+11+1 symbols
// Instructions count - 1+11+1 symbols
// AXYS state - 20
// Processor status - 11
// Tabs - 31
// Address - 6
// Data - 10
// Disassembly - 45
// EOL (/0) - 1
// ------------------------
// 148 symbols total
#define LOG_AXYSTATE_MAX_LEN 21
#define LOG_PROCSTATUS_MAX_LEN 12
#define LOG_TABS_MASK 31
#define LOG_ADDRESS_MAX_LEN 7
#define LOG_DATA_MAX_LEN 11
#define LOG_DISASSEMBLY_MAX_LEN 46

extern HWND hTracer;
extern int log_update_window;
extern volatile int logtofile, logging;
extern int logging_options;
extern bool log_old_emu_paused;

void EnableTracerMenuItems(void);
void LogInstruction(void);
void DoTracer();
void UpdateLogWindow(void);
void OutputLogLine(const char *str, std::vector<uint16>* addressesLog = 0, bool add_newline = true);
