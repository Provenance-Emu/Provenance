#include <string.h>
#include <wchar.h>

typedef size_t (*mini18n_len_func)(const void *);
typedef void * (*mini18n_dup_func)(const void *);
typedef int    (*mini18n_cmp_func)(const void *, const void *);

struct _mini18n_data_t {
	mini18n_len_func len;
	mini18n_dup_func dup;
	mini18n_cmp_func cmp;
};

mini18n_data_t mini18n_wcs = {
	(mini18n_len_func) wcslen,
	(mini18n_dup_func) wcsdup,
	(mini18n_cmp_func) wcscmp
};

int main(int argc, char ** argv) {
}