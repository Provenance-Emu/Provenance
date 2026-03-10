// keyboard support for Pico/SC-3000

// keyboard description
struct key {
	int xpos;
	char *lower, *upper;
	int key;
};

extern struct key *kbd_pico[];
extern struct key *kbd_sc3000[];

#define VKBD_METAS	4
struct vkbd {
	struct key **kbd;
	int	meta[VKBD_METAS][2];	// meta keys (shift, ctrl, etc)

	int	top;			// top or bottom?
	int	shift;			// shifted or normal view?

	int	x,y;			// current key
	int	meta_state;
	int	prev_input;
};

extern struct vkbd vkbd_pico;
extern struct vkbd vkbd_sc3000;

int vkbd_find_xpos(struct key *keys, int xpos);
void vkbd_draw(struct vkbd *vkbd);
int vkbd_update(struct vkbd *vkbd, int input, int *actions);
struct vkbd *vkbd_init(int is_pico);
