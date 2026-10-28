#include "my_application.h"
#include <cstdlib>

int main(int argc, char** argv) {
  // On modern GNOME Wayland sessions, GTK3 queries an obsolete xsettings
  // antialiasing schema key that crashes GLib. Defaulting to x11 (XWayland)
  // prevents this crash seamlessly.
  setenv("GDK_BACKEND", "x11", 0);

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}

