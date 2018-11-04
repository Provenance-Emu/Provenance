#ifndef __ALSA_IATOMIC_H
#define __ALSA_IATOMIC_H

#if defined(__i386__) || defined(__x86_64__)

/*
 * Atomic operations that C can't guarantee us.  Useful for
 * resource counting etc..
 */

#define ATOMIC_SMP_LOCK "lock ; "

/*
 * Make sure gcc doesn't try to be clever and move things around
 * on us. We need to use _exactly_ the address the user gave us,
 * not some alias that contains the same information.
 */
typedef struct { volatile int counter; } atomic_t;

#define ATOMIC_INIT(i)	{ (i) }

/**
 * atomic_read - read atomic variable
 * @v: pointer of type atomic_t
 * 
 * Atomically reads the value of @v.  Note that the guaranteed
 * useful range of an atomic_t is only 24 bits.
 */ 
#define atomic_read(v)		((v)->counter)

/**
 * atomic_set - set atomic variable
 * @v: pointer of type atomic_t
 * @i: required value
 * 
 * Atomically sets the value of @v to @i.  Note that the guaranteed
 * useful range of an atomic_t is only 24 bits.
 */ 
#define atomic_set(v,i)		(((v)->counter) = (i))

/**
 * atomic_add - add integer to atomic variable
 * @i: integer value to add
 * @v: pointer of type atomic_t
 * 
 * Atomically adds @i to @v.  Note that the guaranteed useful range
 * of an atomic_t is only 24 bits.
 */
static __inline__ void atomic_add(int i, atomic_t *v)
{
	__asm__ __volatile__(
		ATOMIC_SMP_LOCK "addl %1,%0"
		:"=m" (v->counter)
		:"ir" (i), "m" (v->counter));
}

/**
 * atomic_sub - subtract the atomic variable
 * @i: integer value to subtract
 * @v: pointer of type atomic_t
 * 
 * Atomically subtracts @i from @v.  Note that the guaranteed
 * useful range of an atomic_t is only 24 bits.
 */
static __inline__ void atomic_sub(int i, atomic_t *v)
{
	__asm__ __volatile__(
		ATOMIC_SMP_LOCK "subl %1,%0"
		:"=m" (v->counter)
		:"ir" (i), "m" (v->counter));
}

/**
 * atomic_sub_and_test - subtract value from variable and test result
 * @i: integer value to subtract
 * @v: pointer of type atomic_t
 * 
 * Atomically subtracts @i from @v and returns
 * true if the result is zero, or false for all
 * other cases.  Note that the guaranteed
 * useful range of an atomic_t is only 24 bits.
 */
static __inline__ int atomic_sub_and_test(int i, atomic_t *v)
{
	unsigned char c;

	__asm__ __volatile__(
		ATOMIC_SMP_LOCK "subl %2,%0; sete %1"
		:"=m" (v->counter), "=qm" (c)
		:"ir" (i), "m" (v->counter) : "memory");
	return c;
}

/**
 * atomic_inc - increment atomic variable
 * @v: pointer of type atomic_t
 * 
 * Atomically increments @v by 1.  Note that the guaranteed
 * useful range of an atomic_t is only 24 bits.
 */ 
static __inline__ void atomic_inc(atomic_t *v)
{
	__asm__ __volatile__(
		ATOMIC_SMP_LOCK "incl %0"
		:"=m" (v->counter)
		:"m" (v->counter));
}

/**
 * atomic_dec - decrement atomic variable
 * @v: pointer of type atomic_t
 * 
 * Atomically decrements @v by 1.  Note that the guaranteed
 * useful range of an atomic_t is only 24 bits.
 */ 
static __inline__ void atomic_dec(atomic_t *v)
{
	__asm__ __volatile__(
		ATOMIC_SMP_LOCK "decl %0"
		:"=m" (v->counter)
		:"m" (v->counter));
}

/**
 * atomic_dec_and_test - decrement and test
 * @v: pointer of type atomic_t
 * 
 * Atomically decrements @v by 1 and
 * returns true if the result is 0, or false for all other
 * cases.  Note that the guaranteed
 * useful range of an atomic_t is only 24 bits.
 */ 
static __inline__ int atomic_dec_and_test(atomic_t *v)
{
	unsigned char c;

	__asm__ __volatile__(
		ATOMIC_SMP_LOCK "decl %0; sete %1"
		:"=m" (v->counter), "=qm" (c)
		:"m" (v->counter) : "memory");
	return c != 0;
}

/**
 * atomic_inc_and_test - increment and test 
 * @v: pointer of type atomic_t
 * 
 * Atomically increments @v by 1
 * and returns true if the result is zero, or false for all
 * other cases.  Note that the guaranteed
 * useful range of an atomic_t is only 24 bits.
 */ 
static __inline__ int atomic_inc_and_test(atomic_t *v)
{
	unsigned char c;

	__asm__ __volatile__(
		ATOMIC_SMP_LOCK "incl %0; sete %1"
		:"=m" (v->counter), "=qm" (c)
		:"m" (v->counter) : "memory");
	return c != 0;
}

/**
 * atomic_add_negative - add and test if negative
 * @v: pointer of type atomic_t
 * @i: integer value to add
 * 
 * Atomically adds @i to @v and returns true
 * if the result is negative, or false when
 * result is greater than or equal to zero.  Note that the guaranteed
 * useful range of an atomic_t is only 24 bits.
 */ 
static __inline__ int atomic_add_negative(int i, atomic_t *v)
{
	unsigned char c;

	__asm__ __volatile__(
		ATOMIC_SMP_LOCK "addl %2,%0; sets %1"
		:"=m" (v->counter), "=qm" (c)
		:"ir" (i), "m" (v->counter) : "memory");
	return c;
}

/* These are x86-specific, used by some header files */
#define atomic_clear_mask(mask, addr) \
__asm__ __volatile__(ATOMIC_SMP_LOCK "andl %0,%1" \
: : "r" (~(mask)),"m" (*addr) : "memory")

#define atomic_set_mask(mask, addr) \
__asm__ __volatile__(ATOMIC_SMP_LOCK "orl %0,%1" \
: : "r" (mask),"m" (*addr) : "memory")

/*
 * Force strict CPU ordering.
 * And yes, this is required on UP too when we're talking
 * to devices.
 *
 * For now, "wmb()" doesn't actually do anything, as all
 * Intel CPU's follow what Intel calls a *Processor Order*,
 * in which all writes are seen in the program order even
 * outside the CPU.
 *
 * I expect future Intel CPU's to have a weaker ordering,
 * but I'd also expect them to finally get their act together
 * and add some real memory barriers if so.
 */
 
#ifdef __i386__
#define mb() 	__asm__ __volatile__ ("lock; addl $0,0(%%esp)": : :"memory")
#define rmb()	mb()
#define wmb()	__asm__ __volatile__ ("": : :"memory")
#else
#define mb() 	asm volatile("mfence":::"memory")
#define rmb()	asm volatile("lfence":::"memory")
#define wmb()	asm volatile("sfence":::"memory")
#endif

#undef ATOMIC_SMP_LOCK

#define IATOMIC_DEFINED		1

#endif /* __i386__ */

#ifdef __ia64__

/*
 * On IA-64, counter must always be volatile to ensure that that the
 * memory accesses are ordered.
 */
typedef struct { volatile int counter; } atomic_t;

#define ATOMIC_INIT(i)		((atomic_t) { (i) })

#define atomic_read(v)		((v)->counter)
#define atomic_set(v,i)		(((v)->counter) = (i))

/* stripped version - we need only 4byte version */
#define ia64_cmpxchg(sem,ptr,old,new,size) \
({ \
	__typeof__(ptr) _p_ = (ptr); \
	__typeof__(new) _n_ = (new); \
	unsigned long _o_, _r_; \
	_o_ = (unsigned int) (long) (old); \
	__asm__ __volatile__ ("mov ar.ccv=%0;;" :: "rO"(_o_)); \
	__asm__ __volatile__ ("cmpxchg4."sem" %0=[%1],%2,ar.ccv" \
			      : "=r"(_r_) : "r"(_p_), "r"(_n_) : "memory"); \
	(__typeof__(old)) _r_; \
})

static __inline__ int
ia64_atomic_add (int i, atomic_t *v)
{
	int old, new;
	// CMPXCHG_BUGCHECK_DECL

	do {
		// CMPXCHG_BUGCHECK(v);
		old = atomic_read(v);
		new = old + i;
	} while (ia64_cmpxchg("acq", v, old, old + i, sizeof(atomic_t)) != old);
	return new;
}

static __inline__ int
ia64_atomic_sub (int i, atomic_t *v)
{
	int old, new;
	// CMPXCHG_BUGCHECK_DECL

	do {
		// CMPXCHG_BUGCHECK(v);
		old = atomic_read(v);
		new = old - i;
	} while (ia64_cmpxchg("acq", v, old, new, sizeof(atomic_t)) != old);
	return new;
}

#define IA64_FETCHADD(tmp,v,n,sz)						\
({										\
	switch (sz) {								\
	      case 4:								\
		__asm__ __volatile__ ("fetchadd4.rel %0=[%1],%2"		\
				      : "=r"(tmp) : "r"(v), "i"(n) : "memory");	\
		break;								\
										\
	      case 8:								\
		__asm__ __volatile__ ("fetchadd8.rel %0=[%1],%2"		\
				      : "=r"(tmp) : "r"(v), "i"(n) : "memory");	\
		break;								\
	}									\
})

#define ia64_fetch_and_add(i,v)							\
({										\
	unsigned long _tmp;								\
	volatile __typeof__(*(v)) *_v = (v);					\
	switch (i) {								\
	      case -16:	IA64_FETCHADD(_tmp, _v, -16, sizeof(*(v))); break;	\
	      case  -8:	IA64_FETCHADD(_tmp, _v,  -8, sizeof(*(v))); break;	\
	      case  -4:	IA64_FETCHADD(_tmp, _v,  -4, sizeof(*(v))); break;	\
	      case  -1:	IA64_FETCHADD(_tmp, _v,  -1, sizeof(*(v))); break;	\
	      case   1:	IA64_FETCHADD(_tmp, _v,   1, sizeof(*(v))); break;	\
	      case   4:	IA64_FETCHADD(_tmp, _v,   4, sizeof(*(v))); break;	\
	      case   8:	IA64_FETCHADD(_tmp, _v,   8, sizeof(*(v))); break;	\
	      case  16:	IA64_FETCHADD(_tmp, _v,  16, sizeof(*(v))); break;	\
	}									\
	(__typeof__(*v)) (_tmp + (i));	/* return new value */			\
})

/*
 * Atomically add I to V and return TRUE if the resulting value is
 * negative.
 */
static __inline__ int
atomic_add_negative (int i, atomic_t *v)
{
	return ia64_atomic_add(i, v) < 0;
}

#define atomic_add_return(i,v)						\
	((__builtin_constant_p(i) &&					\
	  (   (i ==  1) || (i ==  4) || (i ==  8) || (i ==  16)		\
	   || (i == -1) || (i == -4) || (i == -8) || (i == -16)))	\
	 ? ia64_fetch_and_add(i, &(v)->counter)				\
	 : ia64_atomic_add(i, v))

#define atomic_sub_return(i,v)						\
	((__builtin_constant_p(i) &&					\
	  (   (i ==  1) || (i ==  4) || (i ==  8) || (i ==  16)		\
	   || (i == -1) || (i == -4) || (i == -8) || (i == -16)))	\
	 ? ia64_fetch_and_add(-(i), &(v)->counter)			\
	 : ia64_atomic_sub(i, v))

#define atomic_dec_return(v)		atomic_sub_return(1, (v))
#define atomic_inc_return(v)		atomic_add_return(1, (v))

#define atomic_sub_and_test(i,v)	(atomic_sub_return((i), (v)) == 0)
#define atomic_dec_and_test(v)		(atomic_sub_return(1, (v)) == 0)
#define atomic_inc_and_test(v)		(atomic_add_return(1, (v)) != 0)

#define atomic_add(i,v)			atomic_add_return((i), (v))
#define atomic_sub(i,v)			atomic_sub_return((i), (v))
#define atomic_inc(v)			atomic_add(1, (v))
#define atomic_dec(v)			atomic_sub(1, (v))

/*
 * Macros to force memory ordering.  In these descriptions, "previous"
 * and "subsequent" refer to program order; "visible" means that all
 * architecturally visible effects of a memory access have occurred
 * (at a minimum, this means the memory has been read or written).
 *
 *   wmb():	Guarantees that all preceding stores to memory-
 *		like regions are visible before any subsequent
 *		stores and that all following stores will be
 *		visible only after all previous stores.
 *   rmb():	Like wmb(), but for reads.
 *   mb():	wmb()/rmb() combo, i.e., all previous memory
 *		accesses are visible before all subsequent
 *		accesses and vice versa.  This is also known as
 *		a "fence."
 *
 * Note: "mb()" and its variants cannot be used as a fence to order
 * accesses to memory mapped I/O registers.  For that, mf.a needs to
 * be used.  However, we don't want to always use mf.a because (a)
 * it's (presumably) much slower than mf and (b) mf.a is supported for
 * sequential memory pages only.
 */
#define mb()	__asm__ __volatile__ ("mf" ::: "memory")
#define rmb()	mb()
#define wmb()	mb()

#define IATOMIC_DEFINED		1

#endif /* __ia64__ */

#ifdef __alpha__

/*
 * Atomic operations that C can't guarantee us.  Useful for
 * resource counting etc...
 *
 * But use these as seldom as possible since they are much slower
 * than regular operations.
 */


/*
 * Counter is volatile to make sure gcc doesn't try to be clever
 * and move things around on us. We need to use _exactly_ the address
 * the user gave us, not some alias that contains the same information.
 */
typedef struct { volatile int counter; } atomic_t;

#define ATOMIC_INIT(i)	( (atomic_t) { (i) } )

#define atomic_read(v)		((v)->counter)
#define atomic_set(v,i)		((v)->counter = (i))

/*
 * To get proper branch prediction for the main line, we must branch
 * forward to code at the end of this object's .text section, then
 * branch back to restart the operation.
 */

static __inline__ void atomic_add(int i, atomic_t * v)
{
	unsigned long temp;
	__asm__ __volatile__(
	"1:	ldl_l %0,%1\n"
	"	addl %0,%2,%0\n"
	"	stl_c %0,%1\n"
	"	beq %0,2f\n"
	".subsection 2\n"
	"2:	br 1b\n"
	".previous"
	:"=&r" (temp), "=m" (v->counter)
	:"Ir" (i), "m" (v->counter));
}

static __inline__ void atomic_sub(int i, atomic_t * v)
{
	unsigned long temp;
	__asm__ __volatile__(
	"1:	ldl_l %0,%1\n"
	"	subl %0,%2,%0\n"
	"	stl_c %0,%1\n"
	"	beq %0,2f\n"
	".subsection 2\n"
	"2:	br 1b\n"
	".previous"
	:"=&r" (temp), "=m" (v->counter)
	:"Ir" (i), "m" (v->counter));
}

/*
 * Same as above, but return the result value
 */
static __inline__ long atomic_add_return(int i, atomic_t * v)
{
	long temp, result;
	__asm__ __volatile__(
	"1:	ldl_l %0,%1\n"
	"	addl %0,%3,%2\n"
	"	addl %0,%3,%0\n"
	"	stl_c %0,%1\n"
	"	beq %0,2f\n"
	"	mb\n"
	".subsection 2\n"
	"2:	br 1b\n"
	".previous"
	:"=&r" (temp), "=m" (v->counter), "=&r" (result)
	:"Ir" (i), "m" (v->counter) : "memory");
	return result;
}

static __inline__ long atomic_sub_return(int i, atomic_t * v)
{
	long temp, result;
	__asm__ __volatile__(
	"1:	ldl_l %0,%1\n"
	"	subl %0,%3,%2\n"
	"	subl %0,%3,%0\n"
	"	stl_c %0,%1\n"
	"	beq %0,2f\n"
	"	mb\n"
	".subsection 2\n"
	"2:	br 1b\n"
	".previous"
	:"=&r" (temp), "=m" (v->counter), "=&r" (result)
	:"Ir" (i), "m" (v->counter) : "memory");
	return result;
}

#define atomic_dec_return(v) atomic_sub_return(1,(v))
#define atomic_inc_return(v) atomic_add_return(1,(v))

#define atomic_sub_and_test(i,v) (atomic_sub_return((i), (v)) == 0)
#define atomic_dec_and_test(v) (atomic_sub_return(1, (v)) == 0)

#define atomic_inc(v) atomic_add(1,(v))
#define atomic_dec(v) atomic_sub(1,(v))

#define mb() \
__asm__ __volatile__("mb": : :"memory")

#define rmb() \
__asm__ __volatile__("mb": : :"memory")

#define wmb() \
__asm__ __volatile__("wmb": : :"memory")

#define IATOMIC_DEFINED		1

#endif /* __alpha__ */

#ifdef __powerpc__

typedef struct { volatile int counter; } atomic_t;

#define ATOMIC_INIT(i)	{ (i) }

#define atomic_read(v)		((v)->counter)
#define atomic_set(v,i)		(((v)->counter) = (i))

extern void atomic_clear_mask(unsigned long mask, unsigned long *addr);
extern void atomic_set_mask(unsigned long mask, unsigned long *addr);

#define SMP_ISYNC	"\n\tisync"

static __inline__ void atomic_add(int a, atomic_t *v)
{
	int t;

	__asm__ __volatile__(
"1:	lwarx	%0,0,%3		# atomic_add\n\
	add	%0,%2,%0\n\
	stwcx.	%0,0,%3\n\
	bne-	1b"
	: "=&r" (t), "=m" (v->counter)
	: "r" (a), "r" (&v->counter), "m" (v->counter)
	: "cc");
}

static __inline__ int atomic_add_return(int a, atomic_t *v)
{
	int t;

	__asm__ __volatile__(
"1:	lwarx	%0,0,%2		# atomic_add_return\n\
	add	%0,%1,%0\n\
	stwcx.	%0,0,%2\n\
	bne-	1b"
	SMP_ISYNC
	: "=&r" (t)
	: "r" (a), "r" (&v->counter)
	: "cc", "memory");

	return t;
}

static __inline__ void atomic_sub(int a, atomic_t *v)
{
	int t;

	__asm__ __volatile__(
"1:	lwarx	%0,0,%3		# atomic_sub\n\
	subf	%0,%2,%0\n\
	stwcx.	%0,0,%3\n\
	bne-	1b"
	: "=&r" (t), "=m" (v->counter)
	: "r" (a), "r" (&v->counter), "m" (v->counter)
	: "cc");
}

static __inline__ int atomic_sub_return(int a, atomic_t *v)
{
	int t;

	__asm__ __volatile__(
"1:	lwarx	%0,0,%2		# atomic_sub_return\n\
	subf	%0,%1,%0\n\
	stwcx.	%0,0,%2\n\
	bne-	1b"
	SMP_ISYNC
	: "=&r" (t)
	: "r" (a), "r" (&v->counter)
	: "cc", "memory");

	return t;
}

static __inline__ void atomic_inc(atomic_t *v)
{
	int t;

	__asm__ __volatile__(
"1:	lwarx	%0,0,%2		# atomic_inc\n\
	addic	%0,%0,1\n\
	stwcx.	%0,0,%2\n\
	bne-	1b"
	: "=&r" (t), "=m" (v->counter)
	: "r" (&v->counter), "m" (v->counter)
	: "cc");
}

static __inline__ int atomic_inc_return(atomic_t *v)
{
	int t;

	__asm__ __volatile__(
"1:	lwarx	%0,0,%1		# atomic_inc_return\n\
	addic	%0,%0,1\n\
	stwcx.	%0,0,%1\n\
	bne-	1b"
	SMP_ISYNC
	: "=&r" (t)
	: "r" (&v->counter)
	: "cc", "memory");

	return t;
}

static __inline__ void atomic_dec(atomic_t *v)
{
	int t;

	__asm__ __volatile__(
"1:	lwarx	%0,0,%2		# atomic_dec\n\
	addic	%0,%0,-1\n\
	stwcx.	%0,0,%2\n\
	bne-	1b"
	: "=&r" (t), "=m" (v->counter)
	: "r" (&v->counter), "m" (v->counter)
	: "cc");
}

static __inline__ int atomic_dec_return(atomic_t *v)
{
	int t;

	__asm__ __volatile__(
"1:	lwarx	%0,0,%1		# atomic_dec_return\n\
	addic	%0,%0,-1\n\
	stwcx.	%0,0,%1\n\
	bne-	1b"
	SMP_ISYNC
	: "=&r" (t)
	: "r" (&v->counter)
	: "cc", "memory");

	return t;
}

#define atomic_sub_and_test(a, v)	(atomic_sub_return((a), (v)) == 0)
#define atomic_dec_and_test(v)		(atomic_dec_return((v)) == 0)

/*
 * Atomically test *v and decrement if it is greater than 0.
 * The function returns the old value of *v minus 1.
 */
static __inline__ int atomic_dec_if_positive(atomic_t *v)
{
	int t;

	__asm__ __volatile__(
"1:	lwarx	%0,0,%1		# atomic_dec_if_positive\n\
	addic.	%0,%0,-1\n\
	blt-	2f\n\
	stwcx.	%0,0,%1\n\
	bne-	1b"
	SMP_ISYNC
	"\n\
2:"	: "=&r" (t)
	: "r" (&v->counter)
	: "cc", "memory");

	return t;
}

/*
 * Memory barrier.
 * The sync instruction guarantees that all memory accesses initiated
 * by this processor have been performed (with respect to all other
 * mechanisms that access memory).  The eieio instruction is a barrier
 * providing an ordering (separately) for (a) cacheable stores and (b)
 * loads and stores to non-cacheable memory (e.g. I/O devices).
 *
 * mb() prevents loads and stores being reordered across this point.
 * rmb() prevents loads being reordered across this point.
 * wmb() prevents stores being reordered across this point.
 *
 * We can use the eieio instruction for wmb, but since it doesn't
 * give any ordering guarantees about loads, we have to use the
 * stronger but slower sync instruction for mb and rmb.
 */
#define mb()  __asm__ __volatile__ ("sync" : : : "memory")
#define rmb()  __asm__ __volatile__ ("sync" : : : "memory")
#define wmb()  __asm__ __volatile__ ("eieio" : : : "memory")

#define IATOMIC_DEFINED		1

#endif /* __powerpc__ */

#ifdef __mips__

typedef struct { volatile int counter; } atomic_t;

#define ATOMIC_INIT(i)    { (i) }

/*
 * atomic_read - read atomic variable
 * @v: pointer of type atomic_t
 *
 * Atomically reads the value of @v.  Note that the guaranteed
 * useful range of an atomic_t is only 24 bits.
 */
#define atomic_read(v)	((v)->counter)

/*
 * atomic_set - set atomic variable
 * @v: pointer of type atomic_t
 * @i: required value
 *
 * Atomically sets the value of @v to @i.  Note that the guaranteed
 * useful range of an atomic_t is only 24 bits.
 */
#define atomic_set(v,i)	((v)->counter = (i))

/*
 * for MIPS II and better we can use ll/sc instruction, and kernel 2.4.3+
 * will emulate it on MIPS I.
 */

/*
 * atomic_add - add integer to atomic variable
 * @i: integer value to add
 * @v: pointer of type atomic_t
 *
 * Atomically adds @i to @v.  Note that the guaranteed useful range
 * of an atomic_t is only 24 bits.
 */
extern __inline__ void atomic_add(int i, atomic_t * v)
{
	unsigned long temp;

	__asm__ __volatile__(
		".set push                            \n"
		".set mips2                           \n"
		"1:   ll      %0, %1      # atomic_add\n"
		"     addu    %0, %2                  \n"
		"     sc      %0, %1                  \n"
		"     beqz    %0, 1b                  \n"
		".set pop                             \n"
		: "=&r" (temp), "=m" (v->counter)
		: "Ir" (i), "m" (v->counter));
}

/*
 * atomic_sub - subtract the atomic variable
 * @i: integer value to subtract
 * @v: pointer of type atomic_t
 *
 * Atomically subtracts @i from @v.  Note that the guaranteed
 * useful range of an atomic_t is only 24 bits.
 */
extern __inline__ void atomic_sub(int i, atomic_t * v)
{
	unsigned long temp;

	__asm__ __volatile__(
		".set push                            \n"
		".set mips2                           \n"
		"1:   ll      %0, %1      # atomic_sub\n"
		"     subu    %0, %2                  \n"
		"     sc      %0, %1                  \n"
		"     beqz    %0, 1b                  \n"
		".set pop                             \n"
		: "=&r" (temp), "=m" (v->counter)
		: "Ir" (i), "m" (v->counter));
}

/*
 * Same as above, but return the result value
 */
extern __inline__ int atomic_add_return(int i, atomic_t * v)
{
	unsigned long temp, result;

	__asm__ __volatile__(
		".set push               # atomic_add_return\n"
		".set noreorder                             \n"
		".set mips2                                 \n"
		"1:   ll      %1, %2                        \n"
		"     addu    %0, %1, %3                    \n"
		"     sc      %0, %2                        \n"
		"     beqz    %0, 1b                        \n"
		"     addu    %0, %1, %3                    \n"
		".set pop                                   \n"
		: "=&r" (result), "=&r" (temp), "=m" (v->counter)
		: "Ir" (i), "m" (v->counter)
		: "memory");

	return result;
}

extern __inline__ int atomic_sub_return(int i, atomic_t * v)
{
	unsigned long temp, result;

	__asm__ __volatile__(
		".set push                                   \n"
		".set mips2                                  \n"
		".set noreorder           # atomic_sub_return\n"
		"1:   ll    %1, %2                           \n"
		"     subu  %0, %1, %3                       \n"
		"     sc    %0, %2                           \n"
		"     beqz  %0, 1b                           \n"
		"     subu  %0, %1, %3                       \n"
		".set pop                                    \n"
		: "=&r" (result), "=&r" (temp), "=m" (v->counter)
		: "Ir" (i), "m" (v->counter)
		: "memory");

	return result;
}

#define atomic_dec_return(v) atomic_sub_return(1,(v))
#define atomic_inc_return(v) atomic_add_return(1,(v))

/*
 * atomic_sub_and_test - subtract value from variable and test result
 * @i: integer value to subtract
 * @v: pointer of type atomic_t
 *
 * Atomically subtracts @i from @v and returns
 * true if the result is zero, or false for all
 * other cases.  Note that the guaranteed
 * useful range of an atomic_t is only 24 bits.
 */
#define atomic_sub_and_test(i,v) (atomic_sub_return((i), (v)) == 0)

/*
 * atomic_inc_and_test - increment and test
 * @v: pointer of type atomic_t
 *
 * Atomically increments @v by 1
 * and returns true if the result is zero, or false for all
 * other cases.  Note that the guaranteed
 * useful range of an atomic_t is only 24 bits.
 */
#define atomic_inc_and_test(v) (atomic_inc_return(1, (v)) == 0)

/*
 * atomic_dec_and_test - decrement by 1 and test
 * @v: pointer of type atomic_t
 *
 * Atomically decrements @v by 1 and
 * returns true if the result is 0, or false for all other
 * cases.  Note that the guaranteed
 * useful range of an atomic_t is only 24 bits.
 */
#define atomic_dec_and_test(v) (atomic_sub_return(1, (v)) == 0)

/*
 * atomic_inc - increment atomic variable
 * @v: pointer of type atomic_t
 *
 * Atomically increments @v by 1.  Note that the guaranteed
 * useful range of an atomic_t is only 24 bits.
 */
#define atomic_inc(v) atomic_add(1,(v))

/*
 * atomic_dec - decrement and test
 * @v: pointer of type atomic_t
 *
 * Atomically decrements @v by 1.  Note that the guaranteed
 * useful range of an atomic_t is only 24 bits.
 */
#define atomic_dec(v) atomic_sub(1,(v))

/*
 * atomic_add_negative - add and test if negative
 * @v: pointer of type atomic_t
 * @i: integer value to add
 *
 * Atomically adds @i to @v and returns true
 * if the result is negative, or false when
 * result is greater than or equal to zero.  Note that the guaranteed
 * useful range of an atomic_t is only 24 bits.
 *
 * Currently not implemented for MIPS.
 */

#define mb()						\
__asm__ __volatile__(					\
	"# prevent instructions being moved around\n\t"	\
	".set\tnoreorder\n\t"				\
	"# 8 nops to fool the R4400 pipeline\n\t"	\
	"nop;nop;nop;nop;nop;nop;nop;nop\n\t"		\
	".set\treorder"					\
	: /* no output */				\
	: /* no input */				\
	: "memory")
#define rmb() mb()
#define wmb() mb()

#define IATOMIC_DEFINED		1

#endif /* __mips__ */

#ifdef __arm__

/*
 * FIXME: bellow code is valid only for SA11xx
 */

/*
 * Save the current interrupt enable state & disable IRQs
 */
#define local_irq_save(x)					\
	({							\
		unsigned long temp;				\
	__asm__ __volatile__(					\
	"mrs	%0, cpsr		@ local_irq_save\n"	\
"	orr	%1, %0, #128\n"					\
"	msr	cpsr_c, %1"					\
	: "=r" (x), "=r" (temp)					\
	:							\
	: "memory");						\
	})

/*
 * restore saved IRQ & FIQ state
 */
#define local_irq_restore(x)					\
	__asm__ __volatile__(					\
	"msr	cpsr_c, %0		@ local_irq_restore\n"	\
	:							\
	: "r" (x)						\
	: "memory")

#define __save_flags_cli(x) local_irq_save(x)
#define __restore_flags(x) local_irq_restore(x)

typedef struct { volatile int counter; } atomic_t;

#define ATOMIC_INIT(i)	{ (i) }

#define atomic_read(v)	((v)->counter)
#define atomic_set(v,i)	(((v)->counter) = (i))

static __inline__ void atomic_add(int i, volatile atomic_t *v)
{
	unsigned long flags;

	__save_flags_cli(flags);
	v->counter += i;
	__restore_flags(flags);
}

static __inline__ void atomic_sub(int i, volatile atomic_t *v)
{
	unsigned long flags;

	__save_flags_cli(flags);
	v->counter -= i;
	__restore_flags(flags);
}

static __inline__ void atomic_inc(volatile atomic_t *v)
{
	unsigned long flags;

	__save_flags_cli(flags);
	v->counter += 1;
	__restore_flags(flags);
}

static __inline__ void atomic_dec(volatile atomic_t *v)
{
	unsigned long flags;

	__save_flags_cli(flags);
	v->counter -= 1;
	__restore_flags(flags);
}

static __inline__ int atomic_dec_and_test(volatile atomic_t *v)
{
	unsigned long flags;
	int result;

	__save_flags_cli(flags);
	v->counter -= 1;
	result = (v->counter == 0);
	__restore_flags(flags);

	return result;
}

static inline int atomic_add_negative(int i, volatile atomic_t *v)
{
	unsigned long flags;
	int result;

	__save_flags_cli(flags);
	v->counter += i;
	result = (v->counter < 0);
	__restore_flags(flags);

	return result;
}

static __inline__ void atomic_clear_mask(unsigned long mask, unsigned long *addr)
{
	unsigned long flags;

	__save_flags_cli(flags);
	*addr &= ~mask;
	__restore_flags(flags);
}

#define mb() __asm__ __volatile__ ("" : : : "memory")
#define rmb() mb()
#define wmb() mb()

#define IATOMIC_DEFINED		1

#endif /* __arm__ */

#ifdef __sh__

typedef struct { volatile int counter; } atomic_t;

#define ATOMIC_INIT(i)	{ (i) }

#define atomic_read(v)			((v)->counter)
#define atomic_set(v,i)			(((v)->counter) = (i))

#define atomic_dec_return(v)		atomic_sub_return(1,(v))
#define atomic_inc_return(v)		atomic_add_return(1,(v))

#define atomic_sub_and_test(i,v)	(atomic_sub_return((i), (v)) == 0)
#define atomic_dec_and_test(v)		(atomic_sub_return(1, (v)) == 0)
#define atomic_inc_and_test(v)		(atomic_add_return(1, (v)) != 0)

#define atomic_add(i,v)			atomic_add_return((i),(v))
#define atomic_sub(i,v)			atomic_sub_return((i),(v))
#define atomic_inc(v)			atomic_add(1,(v))
#define atomic_dec(v)			atomic_sub(1,(v))

static __inline__ int atomic_add_return(int i, volatile atomic_t *v)
{
	int result;

	asm volatile (
	"	.align	2\n"
	"	mova	99f, r0\n"
	"	mov	r15, r1\n"
	"	mov	#-6, r15\n"
	"	mov.l	@%2, %0\n"
	"	add	%1, %0\n"
	"	mov.l	%0, @%2\n"
	"99:	mov	r1, r15"
	: "=&r"(result)
	: "r"(i), "r"(v)
	: "r0", "r1");

	return result;
}

static __inline__ int atomic_sub_return(int i, volatile atomic_t *v)
{
	int result;

	asm volatile (
	"	.align	2\n"
	"	mova	99f, r0\n"
	"	mov	r15, r1\n"
	"	mov	#-6, r15\n"
	"	mov.l	@%2, %0\n"
	"	sub	%1, %0\n"
	"	mov.l	%0, @%2\n"
	"99:	mov	r1, r15"
	: "=&r"(result)
	: "r"(i), "r"(v)
	: "r0", "r1");

	return result;
}

#define mb() __asm__ __volatile__ ("" : : : "memory")
#define rmb() mb()
#define wmb() mb()

#define IATOMIC_DEFINED		1

#endif /* __sh__ */

#ifdef __bfin__

#include <bfin_fixed_code.h>

typedef struct { volatile int counter; } atomic_t;

#define ATOMIC_INIT(i)   { (i) }

#define atomic_read(v)   ((v)->counter)
#define atomic_set(v,i)  (((v)->counter) = (i))
#define atomic_add(i,v)  bfin_atomic_add32(&(v)->counter, i)
#define atomic_sub(i,v)  bfin_atomic_sub32(&(v)->counter, i)
#define atomic_inc(v)    bfin_atomic_inc32(&(v)->counter);
#define atomic_dec(v)    bfin_atomic_dec32(&(v)->counter);

#define mb() __asm__ __volatile__ ("" : : : "memory")
#define rmb() mb()
#define wmb() mb()

#define IATOMIC_DEFINED 1

#endif /* __bfin__ */

#ifndef IATOMIC_DEFINED
/*
 * non supported architecture.
 */
#warning "Atomic operations are not supported on this architecture."

typedef struct { volatile int counter; } atomic_t;

#define ATOMIC_INIT(i)	{ (i) }

#define atomic_read(v)	((v)->counter)
#define atomic_set(v,i)	(((v)->counter) = (i))
#define atomic_add(i,v) (((v)->counter) += (i))
#define atomic_sub(i,v) (((v)->counter) -= (i))
#define atomic_inc(v)   (((v)->counter)++)
#define atomic_dec(v)   (((v)->counter)--)

#define mb()
#define rmb()
#define wmb()

#define IATOMIC_DEFINED		1

#endif /* IATOMIC_DEFINED */

/*
 *  Atomic read/write
 *  Copyright (c) 2001 by Abramo Bagnara <abramo@alsa-project.org>
 */

/* Max number of times we must spin on a spin-lock calling sched_yield().
   After MAX_SPIN_COUNT iterations, we put the calling thread to sleep. */

#ifndef MAX_SPIN_COUNT
#define MAX_SPIN_COUNT 50
#endif

/* Duration of sleep (in nanoseconds) when we can't acquire a spin-lock
   after MAX_SPIN_COUNT iterations of sched_yield().
   This MUST BE > 2ms.
   (Otherwise the kernel does busy-waiting for real-time threads,
    giving other threads no chance to run.) */

#ifndef SPIN_SLEEP_DURATION
#define SPIN_SLEEP_DURATION 2000001
#endif

typedef struct {
	unsigned int begin, end;
} snd_atomic_write_t;

typedef struct {
	volatile const snd_atomic_write_t *write;
	unsigned int end;
} snd_atomic_read_t;

void snd_atomic_read_wait(snd_atomic_read_t *t);

static inline void snd_atomic_write_init(snd_atomic_write_t *w)
{
	w->begin = 0;
	w->end = 0;
}

static inline void snd_atomic_write_begin(snd_atomic_write_t *w)
{
	w->begin++;
	wmb();
}

static inline void snd_atomic_write_end(snd_atomic_write_t *w)
{
	wmb();
	w->end++;
}

static inline void snd_atomic_read_init(snd_atomic_read_t *r, snd_atomic_write_t *w)
{
	r->write = w;
}

static inline void snd_atomic_read_begin(snd_atomic_read_t *r)
{
	r->end = r->write->end;
	rmb();
}

static inline int snd_atomic_read_ok(snd_atomic_read_t *r)
{
	rmb();
	return r->end == r->write->begin;
}

#endif /* __ALSA_IATOMIC_H */
