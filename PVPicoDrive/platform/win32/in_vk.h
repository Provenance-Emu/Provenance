#ifdef IN_VK

void in_vk_init(void *vdrv);
int  in_vk_update(void *drv_data, const int *binds, int *result);

void in_vk_keydown(int kc);
void in_vk_keyup(int kc);

extern int in_vk_add_pl12;

#else

#define in_vk_init(x)
#define in_vk_update(a,b,c) 0

#endif
