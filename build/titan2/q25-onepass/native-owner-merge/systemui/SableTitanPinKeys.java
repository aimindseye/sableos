package com.android.keyguard.sable;

/** Pure decision policy for physical digit keys. Authentication stays inside Android Keyguard. */
public final class SableTitanPinKeys {
    private SableTitanPinKeys() {}
    private static final int META_NON_TEXT = 0x7000 | 0x70000 | 0x8;
    private static final int META_SHIFT = 0xC1;
    private static final int META_SYM = 0x4;

    public static int digit(int keyCode, int unicode, int number, int meta, int repeats) {
        if (repeats != 0 || (meta & META_NON_TEXT) != 0) return -1;
        if (keyCode >= 7 && keyCode <= 16 && (meta & (META_SHIFT | META_SYM)) == 0) {
            return keyCode - 7;
        }
        if (keyCode >= 144 && keyCode <= 153) return keyCode - 144;
        if (unicode >= '0' && unicode <= '9') return unicode - '0';
        // A hardware KCM can provide the numeric alternative (e.g. Alt+physical letter).
        // Never infer arbitrary letter-to-digit mappings on a different keyboard layout.
        if ((meta & (META_SHIFT | META_SYM)) == 0 && number >= '0' && number <= '9') {
            return number - '0';
        }
        return -1;
    }
}
