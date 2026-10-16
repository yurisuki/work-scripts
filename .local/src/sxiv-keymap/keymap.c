#define _GNU_SOURCE
#include <dlfcn.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>

/* Translate shortcuts to sxiv commands or its existing external key handler. */
int XLookupString(XKeyEvent *event, char *buffer, int size,
                  KeySym *keysym, XComposeStatus *status)
{
    static int (*original)(XKeyEvent *, char *, int, KeySym *, XComposeStatus *);
    static int handler_key_queued;
    if (!original)
        original = dlsym(RTLD_NEXT, "XLookupString");
    int result = original(event, buffer, size, keysym, status);
    if (!keysym)
        return result;
    if (handler_key_queued) {
        handler_key_queued = 0;
        return result;
    }
    unsigned int modifiers = event->state & (ShiftMask | ControlMask | Mod1Mask | Mod4Mask);
    KeySym replacement = NoSymbol;
    if (modifiers == 0 && *keysym == XK_m)
        replacement = XK_greater;
    else if (modifiers == ShiftMask && *keysym == XK_M)
        replacement = XK_less;
    else if (modifiers == 0 && *keysym == XK_comma)
        replacement = XK_minus;
    else if (modifiers == 0 && *keysym == XK_period)
        replacement = XK_plus;
    else if (modifiers == ControlMask && *keysym == XK_0)
        replacement = XK_W;
    else if (((modifiers == ControlMask || modifiers == (ControlMask | ShiftMask)) &&
              (*keysym == XK_c || *keysym == XK_C)) ||
             (modifiers == 0 && *keysym == XK_o) ||
             (modifiers == ShiftMask && *keysym == XK_Delete)) {
        /* Deliver Ctrl+x, then the original shortcut to the external handler. */
        XEvent next = {0};
        next.xkey = *event;
        XPutBackEvent(event->display, &next);
        handler_key_queued = 1;
        event->state = (event->state & ~(ShiftMask | Mod1Mask | Mod4Mask)) | ControlMask;
        *keysym = XK_x;
        if (size > 0)
            buffer[0] = '\030';
        return size > 0 ? 1 : 0;
    }
    if (replacement != NoSymbol) {
        *keysym = replacement;
        event->state &= ~(ShiftMask | ControlMask);
        if (size > 0)
            buffer[0] = (char)replacement;
        return size > 0 ? 1 : 0;
    }
    return result;
}
