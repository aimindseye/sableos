package com.android.dialer.sable;

/** Side-effect-free key policy. Telecom, calls, audio routes and ringing are owned by Android. */
public final class SableTitanInCallKeys {
    private SableTitanInCallKeys() {}
    public enum Action { NONE, ANSWER, TOGGLE_MUTE, TOGGLE_SPEAKER, SHOW_DIALPAD }
    private static final int ANY_MODIFIER = 0xC1 | 0x32 | 0x4 | 0x8 | 0x7000 | 0x70000;
    public static Action decide(int code, int meta, int repeats, boolean incomingAlone,
                                boolean callInProgress, boolean dialpadVisible,
                                boolean spaceAnswers) {
        if (repeats != 0 || (meta & ANY_MODIFIER) != 0) return Action.NONE;
        if (incomingAlone) return (code == 62 && spaceAnswers) ? Action.ANSWER : Action.NONE;
        if (!callInProgress || dialpadVisible) return Action.NONE;
        if (code == 41) return Action.TOGGLE_MUTE; // M
        if (code == 47) return Action.TOGGLE_SPEAKER; // S
        if (code == 32) return Action.SHOW_DIALPAD; // D
        return Action.NONE;
    }
}
