MODULE := src/sqlite

MODULE_OBJS := \
	src/sqlite/sqlite3.o

MODULE_DIRS += \
	src/sqlite

# Include common rules
include $(srcdir)/common.rules
