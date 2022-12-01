/*
 Copyright (c) 2015, OpenEmu Team
 
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * Neither the name of the OpenEmu Team nor the
 names of its contributors may be used to endorse or promote products
 derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <vector>
#include <deque>
#import "OEDiffQueue.h"

struct OEDiffData
{
    uint32_t offset; /* must always be aligned to a 4 byte boundary */
    uint32_t delta;  /* bytes to overwrite */
};

struct OEDeltaPatch
{
    /* Array of changes to make to reconstruct the previous data.
     * The diff only applies to the bytes in common, i.e. if we are
     * reconstructing a 3 KB NSData from a 2 KB NSData we will diff only
     * the first 2 KB. The remaining 1 KB is stored as a flat blob called
     * overflow. To save memory and calls to malloc, the overflow is stored
     * in the items array, after the OEDiffDatas. */
    OEDiffData *items = nullptr;
    
    uint32_t itemCount;      /* # diff data items, overflow blob starts at &items[itemCount] */
    uint32_t overflowOffset; /* offset of the overflow in the reconstructed data */
    uint32_t overflowLength;
    size_t unpackedLength;   /* size of the reconstructed data */
};

struct OEPatch
{
    OEDeltaPatch deltaPatch;
    NSData *fallback;
    
    OEPatch(): fallback(nil) {}
    OEPatch(OEPatch& p) = delete;
    ~OEPatch() {
        free(deltaPatch.items);
    }
};

@implementation OEDiffQueue
{
    NSData *_currentData;
    std::deque<std::unique_ptr<OEPatch> > _patches;
    NSUInteger _capacity;
}

- (instancetype)init
{
    return [self initWithCapacity:NSUIntegerMax];
}

- (instancetype)initWithCapacity:(NSUInteger)capacity
{
    if((self = [super init]))
    {
        _currentData = nil;
        _capacity = MAX(capacity, 2);
        // Note: A capacity <2 crashes in [OEDiffQueue push:]
    }
    return self;
}

- (void)push:(NSData *)aData
{
    if (!_currentData) {
        _currentData = aData;
        return;
    }
    
    OEPatch *newPatch = new OEPatch();
    if (![self _generateDeltaPatch:newPatch->deltaPatch fromData:aData])
        newPatch->fallback = _currentData;
    
    _currentData = aData;
    
    if ([self count] >= _capacity) {
        NSUInteger discrepancy = [self count] - _capacity + 1;
        _patches.erase(_patches.begin(), _patches.begin() + discrepancy);
    }
    
    _patches.push_back(std::unique_ptr<OEPatch>(newPatch));
}

- (BOOL)_generateDeltaPatch:(OEDeltaPatch&)delta fromData:(NSData *)aData
{
    if ([aData length] >= UINT32_MAX)
        return NO;
    
    const char *nextBytes = (const char *)[aData bytes];
    const uint32_t *nextLongs = (const uint32_t *)nextBytes;
    size_t nextLength = [aData length];
    
    char const *currentBytes = (const char *)[_currentData bytes];
    const uint32_t *currentLongs = (const uint32_t *)currentBytes;
    size_t currentLength = [_currentData length];
    delta.unpackedLength = currentLength;
    
    /* the maximum number of diff data items is set to the break-even point
     * between using the diff and storing the original NSData directly. */
    size_t maxItems = nextLength / sizeof(OEDiffData);
    delta.items = (OEDiffData *)malloc((maxItems + 1) * sizeof(OEDiffData));
    
    size_t deltaDataLimit = MIN(nextLength, currentLength) / sizeof(uint32_t);
    size_t deltai, datai;
    size_t realDiffLength;
    for (datai = 0, deltai = 0; datai < deltaDataLimit && deltai < maxItems; datai++) {
        uint32_t nextDelta = currentLongs[datai];
        if (nextLongs[datai] != nextDelta) {
            delta.items[deltai].delta = nextDelta;
            delta.items[deltai].offset = static_cast<uint32_t>(datai * sizeof(uint32_t));
            deltai++;
        }
    }
    delta.itemCount = static_cast<uint32_t>(deltai);
    
    if (deltai >= maxItems)
        goto fail;
    
    if (datai * sizeof(uint32_t) < currentLength) {
        delta.overflowLength = static_cast<uint32_t>(currentLength - datai * sizeof(uint32_t));
        delta.overflowOffset = static_cast<uint32_t>(datai * sizeof(uint32_t));
        if ((maxItems - deltai) * sizeof(OEDiffData) <= delta.overflowLength)
            goto fail;
        
        char *overflowStart = (char *)(delta.items + deltai);
        memcpy(overflowStart, &currentLongs[datai], delta.overflowLength);
    } else {
        delta.overflowLength = 0;
    }
    
    realDiffLength = delta.itemCount * sizeof(OEDiffData) + delta.overflowLength;
    if (void *newbuf = realloc(delta.items, realDiffLength))
        delta.items = (OEDiffData *)newbuf;
    
    return YES;
    
fail:
    free(delta.items);
    delta.items = nullptr;
    return NO;
}

- (NSData *)pop
{
    NSData *prev = _currentData;
    
    if (_patches.size() > 0) {
        OEPatch *patch = _patches.back().get();
        if (patch->fallback)
            _currentData = patch->fallback;
        else
            _currentData = [self _reconstructDataFromDeltaPatch:patch->deltaPatch];
        _patches.pop_back();
    } else {
        _currentData = nil;
    }
    
    return prev;
}

- (NSData *)_reconstructDataFromDeltaPatch:(OEDeltaPatch&)delta
{
    char *buffer = (char *)malloc(delta.unpackedLength);
    size_t sharedLength = MIN(delta.unpackedLength, _currentData.length);
    memcpy(buffer, _currentData.bytes, sharedLength);
    
    uint32_t *bufferLongs = (uint32_t *)buffer;
    uint32_t i;
    for (i = 0; i < delta.itemCount; i++) {
        OEDiffData *data = delta.items + i;
        bufferLongs[data->offset / sizeof(uint32_t)] = data->delta;
    }
    
    if (delta.overflowLength > 0) {
        char *oflstart = buffer + delta.overflowOffset;
        memcpy(oflstart, &(delta.items[i]), delta.overflowLength);
    }
    
    return [NSData dataWithBytesNoCopy:buffer length:delta.unpackedLength];
}

- (NSUInteger)count
{
    if ([self isEmpty])
    {
        return 0;
    }
    
    return 1 + _patches.size();
}

- (BOOL)isEmpty
{
    return _currentData == NULL;
}

@end
