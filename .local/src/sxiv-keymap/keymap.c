#define _GNU_SOURCE
#include <dlfcn.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>

/* Remap unmodified m to sxiv's built-in clockwise rotation shortcut. */
int XLookupString(XKeyEvent *event, char *buffer, int size,
                  KeySym *keysym, XComposeStatus *status)
{
    static int (*original)(XKeyEvent *, char *, int, KeySym *, XComposeStatus *);
    if (!original)
        original = dlsym(RTLD_NEXT, "XLookupString");
    int result = original(event, buffer, size, keysym, status);
    if (keysym && *keysym == XK_m &&
        !(event->state & (ShiftMask | ControlMask | Mod1Mask | Mod4Mask))) {
        *keysym = XK_greater;
        if (result == 1 && size > 0)
            buffer[0] = '>';
    }
    return result;
}
