#include "statemanager.h"
#include "snapshot.h"

/*  State Manager Class that records snapshot data for rewinding
    mostly based on SSNES's rewind code by Themaister
*/

static inline size_t nearest_pow2_size(size_t v)
{
   size_t orig = v;
   v--;
   v |= v >> 1;
   v |= v >> 2;
   v |= v >> 4;
#if SIZE_MAX >= 0xffff
      v |= v >> 8;
#endif
#if SIZE_MAX >= 0xffffffff
      v |= v >> 16;
#endif
#if SIZE_MAX >= 0xffffffffffffffff
      v |= v >> 32;
#endif
   v++;

   size_t next = v;
   size_t prev = v >> 1;

   if ((next - orig) < (orig - prev))
      return next;
   else
      return prev;
}

void StateManager::deallocate() {
    if(buffer) {
        delete [] buffer;
        buffer = NULL;
    }
    if(tmp_state) {
        delete [] tmp_state;
        tmp_state = NULL;
    }
    if(in_state) {
        delete [] in_state;
        in_state = NULL;
    }
}

StateManager::StateManager()
{
    buffer = NULL;
    tmp_state = NULL;
    in_state = NULL;
    init_done = false;
}

StateManager::~StateManager() {
    deallocate();
}

bool StateManager::init(size_t buffer_size) {

    init_done = false;

    deallocate();

    real_state_size = S9xFreezeSize();
    state_size = real_state_size / sizeof(uint32_t); // Works in multiple of 4.

    // We need 4-byte aligned state_size to avoid having to enforce this with unneeded memcpy's!
    if(real_state_size % sizeof(uint32_t)) state_size ++;

    if (buffer_size <= real_state_size) // Need a sufficient buffer size.
        return false;

    top_ptr = 1;

    
    buf_size = nearest_pow2_size(buffer_size) / sizeof(uint64_t); // Works in multiple of 8.
    buf_size_mask = buf_size - 1;

    if (!(buffer = new uint64_t[buf_size]))
        return false;
    if (!(tmp_state = new uint32_t[state_size]))
       return false;
    if (!(in_state = new uint32_t[state_size]))
       return false;

    memset(tmp_state,0,state_size * sizeof(uint32_t));
    memset(in_state,0,state_size * sizeof(uint32_t));

    init_done = true;

    return true;
}

int StateManager::pop()
{ 
    if(!init_done)
        return 0;

    if (first_pop)
    {
      first_pop = false;
      return S9xUnfreezeGameMem((uint8 *)tmp_state,real_state_size);
    }

    top_ptr = (top_ptr - 1) & buf_size_mask;

    if (top_ptr == bottom_ptr) // Our stack is completely empty... :v
    {
      top_ptr = (top_ptr + 1) & buf_size_mask;
      return 0;
    }

    while (buffer[top_ptr])
    {
      // Apply the xor patch.
      uint32_t addr = buffer[top_ptr] >> 32;
      uint32_t xor_ = buffer[top_ptr] & 0xFFFFFFFFU;
      tmp_state[addr] ^= xor_;

      top_ptr = (top_ptr - 1) & buf_size_mask;
    }

    if (top_ptr == bottom_ptr) // Our stack is completely empty... :v
    {
      top_ptr = (top_ptr + 1) & buf_size_mask; 
    }

    return S9xUnfreezeGameMem((uint8 *)tmp_state,real_state_size);
}

void StateManager::reassign_bottom()
{
   bottom_ptr = (top_ptr + 1) & buf_size_mask;
   while (buffer[bottom_ptr]) // Skip ahead until we find the first 0 (boundary for state delta).
      bottom_ptr = (bottom_ptr + 1) & buf_size_mask;
}

void StateManager::generate_delta(const void *data)
{
   bool crossed = false;
   const uint32_t *old_state = tmp_state;
   const uint32_t *new_state = (const uint32_t*)data;

   buffer[top_ptr++] = 0; // For each separate delta, we have a 0 value sentinel in between.
   top_ptr &= buf_size_mask;

   // Check if top_ptr and bottom_ptr crossed each other, which means we need to delete old cruft.
   if (top_ptr == bottom_ptr)
      crossed = true;

   for (uint64_t i = 0; i < state_size; i++)
   {
      uint64_t xor_ = old_state[i] ^ new_state[i];

      // If the data differs (xor != 0), we push that xor on the stack with index and xor.
      // This can be reversed by reapplying the xor.
      // This, if states don't really differ much, we'll save lots of space :)
      // Hopefully this will work really well with save states.
      if (xor_)
      {
         buffer[top_ptr] = (i << 32) | xor_;
         top_ptr = (top_ptr + 1) & buf_size_mask;

         if (top_ptr == bottom_ptr)
            crossed = true;
      }
   }

   if (crossed)
      reassign_bottom();
}

bool StateManager::push()
{
    if(!init_done)
        return false;
    if(!S9xFreezeGameMem((uint8 *)in_state,real_state_size))
        return false;
    generate_delta(in_state);
    uint32 *tmp = tmp_state;
    tmp_state = in_state;
    in_state = tmp;

    first_pop = true;

    return true;
}
