/*  Copyright 2006 Guillaume Duhamel
    Copyright 2005-2006 Fabien Coulon

    This file is part of Yabause.

    Yabause is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Yabause is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Yabause; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#include <gtk/gtk.h>
#include <gdk/gdkkeysyms.h>

#include "yuimem.h"
#include "settings.h"

static void yui_mem_class_init		(YuiMemClass * klass);
static void yui_mem_init		(YuiMem      * yfe);
static void yui_mem_clear		(YuiMem * vdp1);
static void yui_mem_address_changed	(GtkWidget * w, YuiMem * ym);
static void yui_mem_content_changed  ( GtkCellRendererText *cellrenderertext, gchar *arg1, gchar *arg2, YuiMem *ym);
static gboolean yui_mem_pagedown_pressed (GtkWidget *w, gpointer func, gpointer data, gpointer data2, YuiMem *ym);
static gboolean yui_mem_pageup_pressed   (GtkWidget *w, gpointer func, gpointer data, gpointer data2, YuiMem *ym);
static void yui_mem_update		(YuiMem * ym);
static void yui_mem_combo_changed(GtkWidget * w, YuiMem * ym);
static void yui_mem_pagedown_clicked (GtkToolButton * button, YuiMem * ym);
static void yui_mem_pageup_clicked (GtkToolButton * button, YuiMem * ym);

struct { gchar* name; u32 address; } quickAddress[] = 
  { {"VDP2_VRAM_A0", 0x25E00000 },
    {"VDP2_VRAM_A1", 0x25E20000 },
    {"VDP2_VRAM_B0", 0x25E40000 },
    {"VDP2_VRAM_B1", 0x25E60000 },
    {"VDP2_CRAM", 0x25F00000 },
    {"LWRAM", 0x20200000 },
    {"HWRAM", 0x26000000 },
    {"SpriteVRAM", 0x25C00000 },
    {0, 0 } };

GType yui_mem_get_type (void) {
  static GType yfe_type = 0;

  if (!yfe_type)
    {
      static const GTypeInfo yfe_info =
      {
	sizeof (YuiMemClass),
	NULL, /* base_init */
        NULL, /* base_finalize */
	(GClassInitFunc) yui_mem_class_init,
        NULL, /* class_finalize */
	NULL, /* class_data */
        sizeof (YuiMem),
	0,
	(GInstanceInitFunc) yui_mem_init,
        NULL,
      };

      yfe_type = g_type_register_static(GTK_TYPE_WINDOW, "YuiMem", &yfe_info, 0);
    }

  return yfe_type;
}

static void yui_mem_class_init (UNUSED YuiMemClass * klass) {
}

static void yui_mem_init (YuiMem * yv) {
	GtkWidget * view;
	GtkCellRenderer * renderer;
	GtkTreeViewColumn * column;
	GtkAccelGroup *accelGroup;
	GtkToolItem * comboItem, * upbutton, * downbutton;
	GtkWidget * testbox, * vbox;
	gint i;

	gtk_window_set_title(GTK_WINDOW(yv), "Memory dump");

	vbox = gtk_vbox_new(FALSE, 0);
	gtk_container_add(GTK_CONTAINER(yv), vbox);

	yv->toolbar = gtk_toolbar_new();
	gtk_toolbar_set_style(GTK_TOOLBAR(yv->toolbar), GTK_TOOLBAR_ICONS);
	gtk_box_pack_start(GTK_BOX(vbox), yv->toolbar, FALSE, FALSE, 0);

	gtk_toolbar_insert(GTK_TOOLBAR(yv->toolbar), gtk_separator_tool_item_new(), 0);

	comboItem = gtk_tool_item_new();
	gtk_tool_item_set_expand(comboItem, FALSE);
	gtk_toolbar_insert(GTK_TOOLBAR(yv->toolbar), comboItem, 1);

	downbutton = gtk_tool_button_new_from_stock(GTK_STOCK_GO_DOWN);
	g_signal_connect(downbutton, "clicked", G_CALLBACK(yui_mem_pagedown_clicked), yv);
	gtk_toolbar_insert(GTK_TOOLBAR(yv->toolbar), downbutton, 2);

	upbutton = gtk_tool_button_new_from_stock(GTK_STOCK_GO_UP);
	g_signal_connect(upbutton, "clicked", G_CALLBACK(yui_mem_pageup_clicked), yv);
	gtk_toolbar_insert(GTK_TOOLBAR(yv->toolbar), upbutton, 3);

	yv->quickCombo = gtk_combo_box_entry_new_text();

	gtk_entry_set_width_chars(GTK_ENTRY(gtk_bin_get_child(GTK_BIN(yv->quickCombo))), 8);

	for ( i = 0 ; quickAddress[i].name ; i++ )
	  gtk_combo_box_insert_text( GTK_COMBO_BOX( yv->quickCombo ), i, quickAddress[i].name );
	gtk_combo_box_set_active( GTK_COMBO_BOX(yv->quickCombo), 0 );
	g_signal_connect(yv->quickCombo, "changed", G_CALLBACK(yui_mem_combo_changed), yv );
	g_signal_connect(gtk_bin_get_child(GTK_BIN(yv->quickCombo)), "activate", G_CALLBACK(yui_mem_address_changed), yv );

	testbox = gtk_vbox_new(FALSE, 0);
	gtk_box_pack_start(GTK_BOX(testbox), yv->quickCombo, TRUE, FALSE, 0);
	gtk_container_add(GTK_CONTAINER(comboItem), testbox);

	yv->store = gtk_list_store_new(2, G_TYPE_STRING, G_TYPE_STRING);
	view = gtk_tree_view_new_with_model(GTK_TREE_MODEL (yv->store));

	renderer = gtk_cell_renderer_text_new();
	column = gtk_tree_view_column_new_with_attributes("Address", renderer, "text", 0, NULL);
	gtk_tree_view_append_column(GTK_TREE_VIEW (view), column);
	renderer = gtk_cell_renderer_text_new();
	column = gtk_tree_view_column_new_with_attributes("Dump", renderer, "text", 1, NULL);
	gtk_tree_view_append_column(GTK_TREE_VIEW (view), column);
	g_object_set(G_OBJECT(renderer), "editable", TRUE, "mode", GTK_CELL_RENDERER_MODE_EDITABLE, NULL );
	g_signal_connect(G_OBJECT(renderer), "edited", GTK_SIGNAL_FUNC(yui_mem_content_changed), yv );
	gtk_box_pack_start(GTK_BOX(vbox), view, TRUE, TRUE, 0);

	g_signal_connect(G_OBJECT(yv), "delete-event", GTK_SIGNAL_FUNC(yui_mem_destroy), NULL);

	accelGroup = gtk_accel_group_new ();
	gtk_accel_group_connect( accelGroup, GDK_Page_Up, 0, 0, 
				 g_cclosure_new (G_CALLBACK(yui_mem_pageup_pressed), yv, NULL) );
	gtk_accel_group_connect( accelGroup, GDK_Page_Down, 0, 0, 
				 g_cclosure_new (G_CALLBACK(yui_mem_pagedown_pressed), yv, NULL) );
	gtk_window_add_accel_group( GTK_WINDOW( yv ), accelGroup );

	yv->address = 0;
	yv->wLine = 8;

	gtk_window_set_default_size(GTK_WINDOW(yv), 300, -1);
}

GtkWidget * yui_mem_new(YuiWindow * y) {
	GtkWidget * dialog;
	YuiMem * yv;

	dialog = GTK_WIDGET(g_object_new(yui_mem_get_type(), NULL));
	yv = YUI_MEM(dialog);

	yv->yui = y;

	if (!( yv->yui->state & YUI_IS_INIT )) {
	  yui_window_run(yv->yui);
	  yui_window_pause(yv->yui);
	}

	{
		GtkToolItem * play_button, * pause_button;

		play_button = gtk_tool_button_new_from_stock("run");
		gtk_action_connect_proxy(gtk_action_group_get_action(yv->yui->action_group, "run"), GTK_WIDGET(play_button));
		gtk_toolbar_insert(GTK_TOOLBAR(yv->toolbar), GTK_TOOL_ITEM(play_button), 0);

		pause_button = gtk_tool_button_new_from_stock("pause");
		gtk_action_connect_proxy(gtk_action_group_get_action(yv->yui->action_group, "pause"), GTK_WIDGET(pause_button));
		gtk_toolbar_insert(GTK_TOOLBAR(yv->toolbar), GTK_TOOL_ITEM(pause_button), 1);
	}

	yv->paused_handler = g_signal_connect_swapped(yv->yui, "paused", G_CALLBACK(yui_mem_update), yv);
	yv->running_handler = g_signal_connect_swapped(yv->yui, "running", G_CALLBACK(yui_mem_clear), yv);

	if ((yv->yui->state & (YUI_IS_RUNNING | YUI_IS_INIT)) == YUI_IS_INIT)
		yui_mem_update(yv);

	gtk_widget_show_all(GTK_WIDGET(yv));

	return dialog;
}

void yui_mem_destroy(YuiMem * ym) {
	g_signal_handler_disconnect(ym->yui, ym->running_handler);
	g_signal_handler_disconnect(ym->yui, ym->paused_handler);

	gtk_widget_destroy(GTK_WIDGET(ym));
}

static void yui_mem_clear(YuiMem * vdp1) {
}

static void yui_mem_address_changed(GtkWidget * w, YuiMem * ym) {
	sscanf(gtk_entry_get_text(GTK_ENTRY(w)), "%x", &ym->address);
	yui_mem_update(ym);
}

static void yui_mem_combo_changed(GtkWidget * w, YuiMem * ym) {

  gint i = gtk_combo_box_get_active( GTK_COMBO_BOX(w) );

  if (i > -1) {
    ym->address = quickAddress[i].address;
    yui_mem_update(ym);
  }
}

static gint hexaDigitToInt( gchar c ) {

  if (( c >= '0' )&&( c <= '9' )) return c-'0';
  if (( c >= 'a' )&&( c <= 'f' )) return c-'a' + 0xA;
  if (( c >= 'A' )&&( c <= 'F' )) return c-'A' + 0xA;
  return -1;
}

static gboolean yui_mem_pageup_pressed(GtkWidget *w, gpointer func, gpointer data, gpointer data2, YuiMem *ym) {

  ym->address -= 2*ym->wLine;
  yui_mem_update(ym);

  return TRUE;
}

static gboolean yui_mem_pagedown_pressed(GtkWidget *w, gpointer func, gpointer data, gpointer data2, YuiMem *ym) {

  ym->address += 2*ym->wLine;
  yui_mem_update(ym);

  return TRUE;
}

static void yui_mem_pagedown_clicked (GtkToolButton * button, YuiMem * ym) {
  ym->address += 2*ym->wLine;
  yui_mem_update(ym);
}

static void yui_mem_pageup_clicked (GtkToolButton * button, YuiMem * ym) {
  ym->address -= 2*ym->wLine;
  yui_mem_update(ym);
}

static void yui_mem_content_changed( GtkCellRendererText *cellrenderertext,
		      gchar *arg1,
		      gchar *arg2,
		      YuiMem *ym) {
  /* dump line <arg1> has been modified - new content is <arg2> */

  GtkTreeIter iter;
  gint i = atoi(arg1);
  gint j,k;
  gchar *curs;
  u32 addr = ym->address + i*ym->wLine;

  gtk_tree_model_get_iter_from_string( GTK_TREE_MODEL( ym->store ), &iter, arg1 );
  
  /* check the format : wLine*2 hexa digits */
  for ( curs = arg2, j=0 ; *curs ; curs++ )
    if ( hexaDigitToInt( *curs ) != -1 ) j++;

  if ( j != ym->wLine * 2 ) return;

  /* convert */
  for ( curs = arg2, k=-1 ; *curs ; curs++ ) { 

    if ( hexaDigitToInt( *curs )!=-1 ) {

      if ( k==-1 ) k = hexaDigitToInt( *curs );
      else { MappedMemoryWriteByte( addr++, 16*k + hexaDigitToInt( *curs ) ); k = -1;
      }
    }
  }
  yui_window_invalidate(ym->yui);
}

static void yui_mem_update(YuiMem * ym) {
	int i, j;
	GtkTreeIter iter;
	char address[10];
	char dump[30];

	gtk_list_store_clear(ym->store);

	for(i = 0;i < 6;i++) {
		sprintf(address, "%08x", ym->address + (8 * i));
		for(j = 0;j < 8;j++) {
			sprintf(dump + (j * 3), "%02x ", MappedMemoryReadByte(ym->address + (8 * i) + j));
		}

		gtk_list_store_append(ym->store, &iter);
		gtk_list_store_set(GTK_LIST_STORE(ym->store ), &iter, 0, address, 1, dump, -1);
	}

	sprintf( address, "%08X", ym->address );
	gtk_entry_set_text( GTK_ENTRY(gtk_bin_get_child(GTK_BIN(ym->quickCombo))), address );
}
