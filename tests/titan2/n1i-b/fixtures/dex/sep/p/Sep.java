package p;

/**
 * Regression fixture: string constants holding every character that Python's str.splitlines() treats
 * as a line boundary but dexdump may print unescaped (U+0085, U+2028, U+2029) or escaped (VT, FF, FS, GS,
 * RS, CR). Mirrors the android.webkit.FindAddress delimiter constants that broke the D1R1 control oracle.
 * Kept pure ASCII (Unicode escapes only). Compiled with javac --release 8, dexed with dx.
 */
public class Sep {
    static String nel() { return "a\u0085b"; }
    static String lineSeparator() { return "a\u2028b"; }
    static String paragraphSeparator() { return "a\u2029b"; }
    static String controls() { return "v\u000Bf\u000Cfs\u001Cgs\u001Drs\u001Ecr\r"; }
    static String findAddressLike() { return ",\"'\t \u3000\n\u000B\u000C\r\u0085\u2028\u2029"; }
    static String plain() { return "plain"; }
}
