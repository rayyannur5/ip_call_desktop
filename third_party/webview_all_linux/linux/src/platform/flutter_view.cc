#include "plugin/webview_all_linux_plugin_private.h"

#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include <cstring>

static void flutter_view_size_allocate_cb(GtkWidget* widget,
                                          GtkAllocation* allocation,
                                          gpointer user_data) {
  update_flutter_view_input_region(
      static_cast<WebviewAllLinuxPlugin*>(user_data));
}

GtkOverlay* ensure_overlay(WebviewAllLinuxPlugin* self) {
  if (self->overlay != nullptr) {
    return self->overlay;
  }

  FlView* view = fl_plugin_registrar_get_view(self->registrar);
  if (view == nullptr) {
    return nullptr;
  }

  GtkWidget* view_widget = GTK_WIDGET(view);
  GtkWidget* parent = gtk_widget_get_parent(view_widget);
  if (parent == nullptr) {
    return nullptr;
  }

  if (GTK_IS_OVERLAY(parent)) {
    self->overlay = GTK_OVERLAY(parent);
    g_signal_connect(view_widget, "size-allocate",
                     G_CALLBACK(flutter_view_size_allocate_cb), self);
    return self->overlay;
  }

  GtkWidget* toplevel = gtk_widget_get_toplevel(view_widget);
  const gboolean hide_toplevel =
      toplevel != nullptr && GTK_IS_WIDGET(toplevel) &&
      gtk_widget_get_visible(toplevel);
  if (hide_toplevel) {
    gtk_widget_hide(toplevel);
  }

  g_object_ref(view_widget);
  gtk_container_remove(GTK_CONTAINER(parent), view_widget);

  GtkWidget* overlay = gtk_overlay_new();
  g_object_set_data(G_OBJECT(overlay), "webview_all_linux_overlay",
                    GINT_TO_POINTER(1));
  gtk_widget_set_hexpand(overlay, TRUE);
  gtk_widget_set_vexpand(overlay, TRUE);
  gtk_container_add(GTK_CONTAINER(parent), overlay);
  gtk_widget_set_hexpand(view_widget, TRUE);
  gtk_widget_set_vexpand(view_widget, TRUE);
  gtk_container_add(GTK_CONTAINER(overlay), view_widget);
  gtk_widget_realize(overlay);
  gtk_widget_realize(view_widget);
  gtk_widget_show(overlay);
  gtk_widget_show(view_widget);
  gtk_widget_queue_resize(overlay);
  gtk_widget_queue_resize(parent);
  if (hide_toplevel) {
    gtk_widget_show(toplevel);
  }
  g_object_unref(view_widget);

  g_signal_connect(view_widget, "size-allocate",
                   G_CALLBACK(flutter_view_size_allocate_cb), self);

  self->overlay = GTK_OVERLAY(overlay);
  return self->overlay;
}

void update_flutter_view_input_region(WebviewAllLinuxPlugin* self) {
  FlView* view = fl_plugin_registrar_get_view(self->registrar);
  if (view == nullptr) {
    return;
  }

  GtkWidget* view_widget = GTK_WIDGET(view);
  GdkWindow* parent_window = gtk_widget_get_parent_window(view_widget);
  if (parent_window == nullptr) {
    return;
  }

#ifdef GDK_WINDOWING_X11
  // On X11 the input-shape "hole" approach is broken: an input-shape hole on the
  // Flutter view's parent window makes the X server treat the pointer as outside
  // the parent there, so it never descends into the (native) WebKit child window
  // and the click falls through to the window behind the toplevel (focus is
  // lost, the window below is raised). Instead we promote the WebKit window to a
  // native X window (see create_linux_webview) and keep it stacked above the
  // Flutter view, so X delivers clicks to it directly. That makes the hole
  // unnecessary and harmful here, so ensure the parent window has no input shape.
  if (GDK_IS_X11_WINDOW(parent_window)) {
    gdk_window_input_shape_combine_region(parent_window, nullptr, 0, 0);
    return;
  }
#endif

  const gint width = gtk_widget_get_allocated_width(view_widget);
  const gint height = gtk_widget_get_allocated_height(view_widget);
  if (width <= 0 || height <= 0) {
    return;
  }

  cairo_rectangle_int_t full_rect = {0, 0, width, height};
  cairo_region_t* region = cairo_region_create_rectangle(&full_rect);

  GHashTableIter iter;
  gpointer key = nullptr;
  gpointer value = nullptr;
  g_hash_table_iter_init(&iter, self->webviews);
  while (g_hash_table_iter_next(&iter, &key, &value)) {
    LinuxWebView* webview = static_cast<LinuxWebView*>(value);
    if (webview == nullptr || !webview->visible || webview->frame_width <= 0 ||
        webview->frame_height <= 0) {
      continue;
    }

    cairo_rectangle_int_t webview_rect = {
        webview->frame_x, webview->frame_y, webview->frame_width,
        webview->frame_height};
    cairo_region_subtract_rectangle(region, &webview_rect);
  }

  gdk_window_input_shape_combine_region(parent_window, region, 0, 0);
  cairo_region_destroy(region);
}
