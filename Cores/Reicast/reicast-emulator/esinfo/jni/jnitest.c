#include <jni.h>
#include <sys/mman.h>

JNIEXPORT jint JNICALL
Java_com_example_ogles_1info_jnitest_test(JNIEnv * env, jobject  obj)
{
	int sz= 512*1024*1024 + 16*1024*1024;
	void* rv=mmap(0, sz, PROT_NONE, MAP_PRIVATE | MAP_ANON, -1, 0);
	if (rv != MAP_FAILED) {
		munmap(rv,sz);
	}
	return rv != MAP_FAILED;
}
