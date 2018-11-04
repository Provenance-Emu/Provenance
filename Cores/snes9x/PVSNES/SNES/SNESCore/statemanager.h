#ifndef STATEMANAGER_H
#define STATEMANAGER_H

/*  State Manager Class that records snapshot data for rewinding
    mostly based on SSNES's rewind code by Themaister
*/

#include "snes9x.h"

class StateManager {
private:
    uint64_t *buffer;
    size_t buf_size;
    size_t buf_size_mask;
    uint32_t *tmp_state;
    uint32_t *in_state;
    size_t top_ptr;
    size_t bottom_ptr;
    size_t state_size;
    size_t real_state_size;
    bool init_done;
    bool first_pop;
    
    void reassign_bottom();
    void generate_delta(const void *data);
    void deallocate();
public:
    StateManager();
    ~StateManager();
    bool init(size_t buffer_size);
    int pop();
    bool push();
};

#endif // STATEMANAGER_H
