


// this structure represent a linear block of vram
typedef struct VramBlock_t
{
	VramBlockT	*pPrev;
	VramBlockT	*pNext;

	struct VramHeap_t *pHeap;   // heap that this block belongs to

	Uint16	uAddr;		 		// start address of block
	Uint16	uSize;		 		// end address of block
} VramBlockT;

typedef struct VramBlockList_t
{
	VramBlockT *pHead;		// first block of heap
	VramBlockT *pTail;		// last block of heap
} VramBlockListT;

// a heap itself resides witin a block
// a heap is a collection of vram "sub-blocks"
typedef struct VramHeap_t
{
	VramBlockT *pBlock;     // block that this heap resides in (parent block)

	VramBlockListT UsedBlocks;	// list of used blocks
	VramBlockListT FreeBlocks;	// list of free blocks
} VramHeapT;


static VramBlockListT _Vram_FreeBlocks;

static VramBlockT *_VramAllocBlock()
{
	return NULL;
}

static void _VramFreeBlock(VramBlockT *pBlock)
{
}



void VramHeapNew(VramHeapT *pHeap)
{
	pHeap->pBlock = NULL;   // heap has not been bound to a block
	pHeap->pHead = NULL;
	pHeap->pTali = NULL;
}

VramBlockT *VramHeapAlloc(VramHeapT *pHeap, Uint32 uSize)
{
	return NULL;
}
