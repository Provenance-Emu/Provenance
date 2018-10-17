/* copyright Patrick Kooman, 2002

  Lightweight C & C++ profiler. Works both in
  debug- and release mode. For more info, read:

  http://www.2dgame-tutorial.com/sdl/profile.htm

  You are free to use / modify / re-distribute this code.

  */

/*! \file profile.c
    \brief Lightweight C & C++ profiler.
*/

#if !defined(SYS_PROFILE_H) && !defined(DONT_PROFILE)

#include "profile.h"

/* The time when the profiler initializes */
clock_t g_init_time ;
/* Entries */
entry_t g_tag [NUM_TAGS] ;
/* "high-water-mark" */
int g_i_hwm = 0 ;
/* Is ProfileInit called? */
int g_init = 0 ;

/* Looks up given tag and returns the name,
 of 0 if not found. */
static entry_t* LookupTag (char* str_tag) {
  int i ;
  for (i = 0; i < g_i_hwm; ++i) {
    if (strcmp (g_tag [i].str_name, str_tag) == 0) {
      return &g_tag [i] ;
    }
  }
  return 0 ;
}

/* Checks whether the given tag is already started (nesting).
   This is true when an entry with the given name is found,
   for which the start_time_t is not 0. */
static int Nested (char* str_tag) {
  int i ;
  for (i = 0; i < g_i_hwm; ++i) {
    if (strcmp (g_tag [i].str_name, str_tag) == 0 && g_tag [i].start_time > -1) {
      /* Already 'running': nested*/
      return 1 ;
    }
  }
  /* Not running: not nested */
  return 0 ;
}

/* Adds the given tag and return the entry it is stored into */
static entry_t* AddTag (char* str_tag) {
  if (g_i_hwm + 1 == NUM_TAGS) {
    /* Full */
    return 0 ;
  }
  /* Copy the name */
  strcpy (g_tag [g_i_hwm].str_name, str_tag) ;
  g_tag [g_i_hwm].start_time = -1 ;
  /* Increase the high-water-mark but return the current index */
  return &g_tag [g_i_hwm++] ;
}

/* Compare function for 'qsort' */
static int CompareEntries (const void* p_1, const void* p_2) {
  entry_t* p_entry1, *p_entry2 ;
  /* Cast elements to entry_t type */
  p_entry1 = (entry_t*) p_1 ;
  p_entry2 = (entry_t*) p_2 ;
  /* Compare */
  return p_entry2->l_total_ms - p_entry1->l_total_ms ; 
}

/* Called on the first start-call. It receives the start-time */
static void Init (void) {
  memset (g_tag, 0, sizeof (g_tag)) ;
  /* Retreive the time */
  g_init_time = clock () ;
  /* Flag that this function has been called */
  g_init = 1 ;
  g_i_hwm = 0 ;
}

/* Prints profiling statistice to stdout, 
sorted by percentage (descending) */
void ProfilePrint (void) {
  int i ;
  long l_prof_time ;
  if (g_i_hwm == 0) {
    fprintf (stdout, "ProfilePrint: nothing to print.\n") ;
    return ;
  }
  /* Retreive the time */
  l_prof_time = clock () - g_init_time ;
  if (l_prof_time == 0) {
    /* Avoid division by 0 */
    fprintf (stdout, "Warning: nothing to show because timer ran for less than 1 clock-tick.") ;
  }
  /* Print warnings for tags which are not stopped. */
  for (i = 0; i < g_i_hwm; ++i) {
    if (g_tag [i].i_stopped == 0) {
      g_tag [i].l_total_ms += clock () - g_tag [i].start_time ;
      fprintf (stdout, "Warning: \"%s\" started but not stopped. (Done now, but result may be over-expensive!)\n", g_tag [i].str_name) ;
    }
  }
  /* Sort the array desending */
  qsort (&g_tag, g_i_hwm, sizeof (entry_t), CompareEntries) ;
  fprintf (stdout, "Profiler results (descending by percentage):\n\n") ;
  for (i = 0; i < g_i_hwm; ++i) {
    /* Print statistics */
    fprintf (stdout, "< calls: %2d, total ms: %3d, percentage: %3.1f%% > - \"%s\"\n",
      g_tag [i].i_calls, 
      (int) ((double) g_tag [i].l_total_ms / CLOCKS_PER_SEC * 1000),
      (double) g_tag [i].l_total_ms / l_prof_time * 100,
      g_tag [i].str_name) ;
  }
}

/* Starts timer for given tag. If it does not exist yet,
 it is added.

  Note: 1. The tag may not be nested with the same name
        2. The tag may not equal "" */
void ProfileStart (char* str_tag) {
  entry_t* p_entry ;
  /* One the first call, we must initialize the profiler. */
  if (!g_init) {
    Init () ;
  }
  /* Test for "" */
  if (*str_tag == '\0') {
    fprintf (stdout, "ERROR in ProfileStart: a tag may not be \"\". Call is denied.") ; 
    return ;
  }
  /* Search the entry with the given name */
  p_entry = LookupTag (str_tag) ;
  if (!p_entry) {
    /* New tag, add it*/
    p_entry = AddTag (str_tag) ;
    if (!p_entry) {
      fprintf (stdout, "WARNING in ProfileStart: no more space to store the tag (\"%s\"). Increase NUM_TAGS in \"profile.h\". Call is denied.\n", str_tag) ;
      return ;
    }    
  }
  /* Check for nesting of equal tag.*/
  if (Nested (str_tag)) {
    fprintf (stdout, "ERROR in ProfileStart: nesting of equal tags not allowed (\"%s\"). Call is denied.\n", str_tag) ;
    return ;
  }
  /* Increase the number of hits */
  ++p_entry->i_calls ;
  /* Set the start time */
  p_entry->start_time = clock () ;
  p_entry->i_stopped = 0 ;
}

/* Stops timer for given tag. Checks for existence.
 Adds the time between now and the Start call to the
 total time.*/
void ProfileStop (char* str_tag) {
  clock_t end_time ;
  entry_t* p_entry ;
  /* Test for "" */
  if (*str_tag == '\0') {
    fprintf (stdout, "ERROR in ProfileStop: a tag may not be \"\". Call is denied.") ; 
    return ;
  }
  /* Check for a existing name */
  p_entry = LookupTag (str_tag) ;
  if (!p_entry) {
    fprintf (stdout, "WARNING in ProfileStop: tag \"%s\" was never started. Call is denied.\n", str_tag) ;
    return ;
  }    
  /* Get the time */
  end_time = clock () ;
  p_entry->l_total_ms += end_time - p_entry->start_time ;
  /* Reset */
  p_entry->start_time = -1 ;
  p_entry->i_stopped = 1 ;
}

/* Resets the profiler. */
void ProfileReset (void) {
  Init () ;
}

#endif /* !SYS_PROFILE_H && !DONT_PROFILE */

