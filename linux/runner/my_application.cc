#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  // The main window; a second activation (for example a second launch that
  // handed off to this instance) presents it instead of opening another.
  GtkWindow* window;
  FlView* view;
  // Edge resize cursor shown over the window border, and the cursor Flutter
  // had set before it, restored when the pointer moves back inside.
  GdkCursor* resize_cursor;
  GdkCursor* saved_cursor;
  gboolean cursor_overridden;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static constexpr const char kWindowTitle[] = "Serlink";
static constexpr gint kDefaultWindowWidth = 1280;
static constexpr gint kDefaultWindowHeight = 800;
static constexpr gint kMinimumWindowWidth = 960;
static constexpr gint kMinimumWindowHeight = 600;
// The window is undecorated, so the runner provides the resize border that a
// window manager frame (or the Win32 non-client hit test) would.
static constexpr gdouble kResizeBorder = 6;
static constexpr gdouble kResizeCorner = 16;

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

static gboolean is_window_maximized(GtkWindow* window) {
  GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
  if (gdk_window == nullptr) {
    return FALSE;
  }
  return (gdk_window_get_state(gdk_window) & GDK_WINDOW_STATE_MAXIMIZED) != 0;
}

static void present_window(GtkWindow* window) {
  gtk_window_deiconify(window);
  gtk_window_present(window);
  GtkWidget* child = gtk_bin_get_child(GTK_BIN(window));
  if (child != nullptr) {
    gtk_widget_grab_focus(child);
  }
}

// FlView delivers pointer events through an internal GtkEventBox child.
static GtkWidget* find_view_event_box(FlView* view) {
  GtkWidget* result = nullptr;
  GList* children = gtk_container_get_children(GTK_CONTAINER(view));
  for (GList* item = children; item != nullptr; item = item->next) {
    if (GTK_IS_EVENT_BOX(item->data)) {
      result = GTK_WIDGET(item->data);
      break;
    }
  }
  g_list_free(children);
  return result;
}

// Once the window manager owns a move drag it also receives the button
// release, so Flutter would still consider the primary button held and
// swallow the next click. Deliver the release Flutter is waiting for.
static void release_flutter_pointer(FlView* view, GdkDevice* pointer) {
  GtkWidget* event_box = find_view_event_box(view);
  GdkWindow* event_window =
      event_box == nullptr ? nullptr : gtk_widget_get_window(event_box);
  if (event_window == nullptr || pointer == nullptr) {
    return;
  }

  gdouble x = 0;
  gdouble y = 0;
  GdkModifierType state = static_cast<GdkModifierType>(0);
  gdk_window_get_device_position_double(event_window, pointer, &x, &y,
                                        &state);
  gint root_x = 0;
  gint root_y = 0;
  gdk_window_get_root_coords(event_window, static_cast<gint>(x),
                             static_cast<gint>(y), &root_x, &root_y);

  GdkEvent* release = gdk_event_new(GDK_BUTTON_RELEASE);
  release->button.window = GDK_WINDOW(g_object_ref(event_window));
  release->button.send_event = TRUE;
  release->button.time = gtk_get_current_event_time();
  release->button.x = x;
  release->button.y = y;
  release->button.x_root = root_x;
  release->button.y_root = root_y;
  release->button.state =
      static_cast<guint>(state & GDK_MODIFIER_MASK) | GDK_BUTTON1_MASK;
  release->button.button = GDK_BUTTON_PRIMARY;
  gdk_event_set_device(release, pointer);
  gtk_widget_event(event_box, release);
  gdk_event_free(release);
}

static void begin_window_move(MyApplication* self) {
  GtkWindow* window = self->window;
  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window));
  GdkSeat* seat = gdk_display_get_default_seat(display);
  GdkDevice* pointer = seat == nullptr ? nullptr : gdk_seat_get_pointer(seat);
  gint x_root = 0;
  gint y_root = 0;
  if (pointer != nullptr) {
    gdk_device_get_position(pointer, nullptr, &x_root, &y_root);
  }
  gtk_window_begin_move_drag(window, GDK_BUTTON_PRIMARY, x_root, y_root,
                             gtk_get_current_event_time());
  release_flutter_pointer(self->view, pointer);
}

static FlMethodResponse* success_response(FlValue* value = nullptr) {
  return FL_METHOD_RESPONSE(fl_method_success_response_new(value));
}

static void window_method_call_cb(FlMethodChannel* channel,
                                  FlMethodCall* method_call,
                                  gpointer user_data) {
  (void)channel;
  MyApplication* self = MY_APPLICATION(user_data);
  GtkWindow* window = self->window;
  const gchar* method = fl_method_call_get_name(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (window == nullptr) {
    response = FL_METHOD_RESPONSE(fl_method_error_response_new(
        "no_window", "The Serlink window is not available.", nullptr));
  } else if (g_strcmp0(method, "activate") == 0) {
    present_window(window);
    response = success_response();
  } else if (g_strcmp0(method, "minimize") == 0) {
    gtk_window_iconify(window);
    response = success_response();
  } else if (g_strcmp0(method, "toggleMaximize") == 0) {
    // The window manager applies this request after the method returns.
    const gboolean maximize = !is_window_maximized(window);
    if (maximize) {
      gtk_window_maximize(window);
    } else {
      gtk_window_unmaximize(window);
    }
    g_autoptr(FlValue) maximized = fl_value_new_bool(maximize);
    response = success_response(maximized);
  } else if (g_strcmp0(method, "isMaximized") == 0) {
    g_autoptr(FlValue) maximized =
        fl_value_new_bool(is_window_maximized(window));
    response = success_response(maximized);
  } else if (g_strcmp0(method, "close") == 0) {
    gtk_window_close(window);
    response = success_response();
  } else if (g_strcmp0(method, "startDrag") == 0) {
    begin_window_move(self);
    response = success_response();
  } else {
    response =
        FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void register_window_channel(MyApplication* self, FlView* view) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "serlink/window", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, window_method_call_cb,
                                            self, nullptr);
  g_object_set_data_full(G_OBJECT(self->window), "serlink-window-channel",
                         channel, g_object_unref);
}

// Translates event coordinates into the toplevel window's coordinates.
static gboolean window_coords_for_event(GtkWindow* window,
                                        const GdkEvent* event,
                                        gdouble* x,
                                        gdouble* y) {
  gdouble event_x = 0;
  gdouble event_y = 0;
  if (event == nullptr || !gdk_event_get_coords(event, &event_x, &event_y)) {
    return FALSE;
  }
  GdkWindow* target = gtk_widget_get_window(GTK_WIDGET(window));
  GdkWindow* current = gdk_event_get_window(event);
  while (current != nullptr && current != target) {
    gdk_window_coords_to_parent(current, event_x, event_y, &event_x, &event_y);
    current = gdk_window_get_parent(current);
  }
  if (current != target) {
    return FALSE;
  }
  *x = event_x;
  *y = event_y;
  return TRUE;
}

static gboolean resize_edge_at(GtkWindow* window,
                               gdouble x,
                               gdouble y,
                               GdkWindowEdge* edge) {
  GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
  if (gdk_window == nullptr || !gtk_window_get_resizable(window)) {
    return FALSE;
  }
  const GdkWindowState state = gdk_window_get_state(gdk_window);
  if ((state & (GDK_WINDOW_STATE_MAXIMIZED | GDK_WINDOW_STATE_FULLSCREEN)) !=
      0) {
    return FALSE;
  }

  const gdouble width = gtk_widget_get_allocated_width(GTK_WIDGET(window));
  const gdouble height = gtk_widget_get_allocated_height(GTK_WIDGET(window));
  const gboolean left = x < kResizeBorder;
  const gboolean right = x >= width - kResizeBorder;
  const gboolean top = y < kResizeBorder;
  const gboolean bottom = y >= height - kResizeBorder;
  const gboolean near_left = x < kResizeCorner;
  const gboolean near_right = x >= width - kResizeCorner;
  const gboolean near_top = y < kResizeCorner;
  const gboolean near_bottom = y >= height - kResizeCorner;

  if ((top && near_left) || (left && near_top)) {
    *edge = GDK_WINDOW_EDGE_NORTH_WEST;
  } else if ((top && near_right) || (right && near_top)) {
    *edge = GDK_WINDOW_EDGE_NORTH_EAST;
  } else if ((bottom && near_left) || (left && near_bottom)) {
    *edge = GDK_WINDOW_EDGE_SOUTH_WEST;
  } else if ((bottom && near_right) || (right && near_bottom)) {
    *edge = GDK_WINDOW_EDGE_SOUTH_EAST;
  } else if (top) {
    *edge = GDK_WINDOW_EDGE_NORTH;
  } else if (bottom) {
    *edge = GDK_WINDOW_EDGE_SOUTH;
  } else if (left) {
    *edge = GDK_WINDOW_EDGE_WEST;
  } else if (right) {
    *edge = GDK_WINDOW_EDGE_EAST;
  } else {
    return FALSE;
  }
  return TRUE;
}

static const gchar* resize_cursor_name(GdkWindowEdge edge) {
  switch (edge) {
    case GDK_WINDOW_EDGE_NORTH_WEST:
      return "nw-resize";
    case GDK_WINDOW_EDGE_NORTH:
      return "n-resize";
    case GDK_WINDOW_EDGE_NORTH_EAST:
      return "ne-resize";
    case GDK_WINDOW_EDGE_WEST:
      return "w-resize";
    case GDK_WINDOW_EDGE_EAST:
      return "e-resize";
    case GDK_WINDOW_EDGE_SOUTH_WEST:
      return "sw-resize";
    case GDK_WINDOW_EDGE_SOUTH:
      return "s-resize";
    case GDK_WINDOW_EDGE_SOUTH_EAST:
      return "se-resize";
  }
  return "default";
}

static void restore_cursor(MyApplication* self) {
  if (!self->cursor_overridden) {
    return;
  }
  GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(self->window));
  // Keep any cursor Flutter set while the pointer was over the border.
  if (gdk_window != nullptr &&
      gdk_window_get_cursor(gdk_window) == self->resize_cursor) {
    gdk_window_set_cursor(gdk_window, self->saved_cursor);
  }
  g_clear_object(&self->resize_cursor);
  g_clear_object(&self->saved_cursor);
  self->cursor_overridden = FALSE;
}

static void update_resize_cursor(MyApplication* self, gdouble x, gdouble y) {
  GdkWindowEdge edge;
  if (!resize_edge_at(self->window, x, y, &edge)) {
    restore_cursor(self);
    return;
  }
  GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(self->window));
  if (!self->cursor_overridden) {
    GdkCursor* current = gdk_window_get_cursor(gdk_window);
    self->saved_cursor =
        current == nullptr ? nullptr : GDK_CURSOR(g_object_ref(current));
    self->cursor_overridden = TRUE;
  }
  g_clear_object(&self->resize_cursor);
  self->resize_cursor = gdk_cursor_new_from_name(
      gdk_window_get_display(gdk_window), resize_cursor_name(edge));
  gdk_window_set_cursor(gdk_window, self->resize_cursor);
}

static void resize_motion_cb(GtkEventControllerMotion* controller,
                             gdouble widget_x,
                             gdouble widget_y,
                             gpointer user_data) {
  (void)controller;
  (void)widget_x;
  (void)widget_y;
  MyApplication* self = MY_APPLICATION(user_data);
  GdkEvent* event = gtk_get_current_event();
  gdouble x = 0;
  gdouble y = 0;
  if (window_coords_for_event(self->window, event, &x, &y)) {
    update_resize_cursor(self, x, y);
  }
  if (event != nullptr) {
    gdk_event_free(event);
  }
}

static void resize_leave_cb(GtkEventControllerMotion* controller,
                            gpointer user_data) {
  (void)controller;
  restore_cursor(MY_APPLICATION(user_data));
}

// Runs in the capture phase, before FlView sees the press, and claims presses
// on the border so they resize the window instead of reaching Flutter. This
// mirrors how GTK's own client-side decorations start a resize.
static void resize_pressed_cb(GtkGestureMultiPress* gesture,
                              gint n_press,
                              gdouble widget_x,
                              gdouble widget_y,
                              gpointer user_data) {
  (void)n_press;
  (void)widget_x;
  (void)widget_y;
  MyApplication* self = MY_APPLICATION(user_data);
  GdkEventSequence* sequence =
      gtk_gesture_single_get_current_sequence(GTK_GESTURE_SINGLE(gesture));
  const GdkEvent* event =
      gtk_gesture_get_last_event(GTK_GESTURE(gesture), sequence);
  gdouble x = 0;
  gdouble y = 0;
  GdkWindowEdge edge;
  if (!window_coords_for_event(self->window, event, &x, &y) ||
      !resize_edge_at(self->window, x, y, &edge)) {
    gtk_gesture_set_state(GTK_GESTURE(gesture), GTK_EVENT_SEQUENCE_DENIED);
    return;
  }

  gdouble root_x = 0;
  gdouble root_y = 0;
  gdk_event_get_root_coords(event, &root_x, &root_y);
  gtk_gesture_set_state(GTK_GESTURE(gesture), GTK_EVENT_SEQUENCE_CLAIMED);
  gtk_window_begin_resize_drag(
      self->window, edge,
      gtk_gesture_single_get_current_button(GTK_GESTURE_SINGLE(gesture)),
      static_cast<gint>(root_x), static_cast<gint>(root_y),
      gdk_event_get_time(event));
  gtk_event_controller_reset(GTK_EVENT_CONTROLLER(gesture));
}

static void install_resize_border(MyApplication* self) {
  GtkWidget* widget = GTK_WIDGET(self->window);

  GtkGesture* press = gtk_gesture_multi_press_new(widget);
  gtk_gesture_single_set_button(GTK_GESTURE_SINGLE(press), GDK_BUTTON_PRIMARY);
  gtk_event_controller_set_propagation_phase(GTK_EVENT_CONTROLLER(press),
                                             GTK_PHASE_CAPTURE);
  g_signal_connect(press, "pressed", G_CALLBACK(resize_pressed_cb), self);
  // GTK 3 event controllers are not owned by their widget.
  g_object_set_data_full(G_OBJECT(widget), "serlink-resize-press", press,
                         g_object_unref);

  GtkEventController* motion = gtk_event_controller_motion_new(widget);
  gtk_event_controller_set_propagation_phase(motion, GTK_PHASE_CAPTURE);
  g_signal_connect(motion, "motion", G_CALLBACK(resize_motion_cb), self);
  g_signal_connect(motion, "leave", G_CALLBACK(resize_leave_cb), self);
  g_object_set_data_full(G_OBJECT(widget), "serlink-resize-motion", motion,
                         g_object_unref);
}

static void set_window_icon(GtkWindow* window) {
  // Release bundles carry the icon next to the executable; installed
  // packages also provide it through the hicolor icon theme.
  g_autofree gchar* executable = g_file_read_link("/proc/self/exe", nullptr);
  if (executable != nullptr) {
    g_autofree gchar* directory = g_path_get_dirname(executable);
    g_autofree gchar* icon = g_build_filename(directory, "data", "icons",
                                              APPLICATION_ID ".png", nullptr);
    if (g_file_test(icon, G_FILE_TEST_IS_REGULAR) &&
        gtk_window_set_icon_from_file(window, icon, nullptr)) {
      return;
    }
  }
  gtk_window_set_icon_name(window, APPLICATION_ID);
}

static void configure_window_chrome(GtkWindow* window) {
  gtk_window_set_decorated(window, FALSE);
  gtk_window_set_resizable(window, TRUE);
  GdkGeometry geometry = {};
  geometry.min_width = kMinimumWindowWidth;
  geometry.min_height = kMinimumWindowHeight;
  gtk_window_set_geometry_hints(window, nullptr, &geometry, GDK_HINT_MIN_SIZE);

  GdkScreen* screen = gtk_window_get_screen(window);
  GdkVisual* visual = gdk_screen_get_rgba_visual(screen);
  if (visual != nullptr) {
    gtk_widget_set_visual(GTK_WIDGET(window), visual);
    gtk_widget_set_app_paintable(GTK_WIDGET(window), TRUE);
  }
}

static void window_destroy_cb(GtkWidget* widget, gpointer user_data) {
  (void)widget;
  MyApplication* self = MY_APPLICATION(user_data);
  g_clear_object(&self->resize_cursor);
  g_clear_object(&self->saved_cursor);
  self->cursor_overridden = FALSE;
  self->window = nullptr;
  self->view = nullptr;
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  if (self->window != nullptr) {
    present_window(self->window);
    return;
  }

  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  self->window = window;
  g_signal_connect(window, "destroy", G_CALLBACK(window_destroy_cb), self);

  configure_window_chrome(window);
  gtk_window_set_title(window, kWindowTitle);
  set_window_icon(window);
  gtk_window_set_default_size(window, kDefaultWindowWidth,
                              kDefaultWindowHeight);
  gtk_window_set_position(window, GTK_WIN_POS_CENTER);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  self->view = view;
  GdkRGBA background_color;
  // Transparent so the rounded window corners Flutter draws stay rounded.
  gdk_rgba_parse(&background_color, "#00000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));
  register_window_channel(self, view);
  install_resize_border(self);

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  // In release builds a second launch is a remote instance: activating it
  // presents the running window and this process exits.
  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->resize_cursor);
  g_clear_object(&self->saved_cursor);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

#ifdef NDEBUG
  // One Serlink process owns the local profile. As on Windows, release
  // builds hand a second launch off to the running instance over D-Bus.
  constexpr GApplicationFlags kFlags = static_cast<GApplicationFlags>(0);
#else
  constexpr GApplicationFlags kFlags = G_APPLICATION_NON_UNIQUE;
#endif
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     kFlags, nullptr));
}
