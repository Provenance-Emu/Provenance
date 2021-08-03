
void CycloneInitIdleJT(void *jt);
void CycloneFinishIdleJT(void *jt);

#define CycloneInitIdle() \
	CycloneInitIdleJT(CycloneJumpTab)
#define CycloneFinishIdle() \
	CycloneFinishIdleJT(CycloneJumpTab)
