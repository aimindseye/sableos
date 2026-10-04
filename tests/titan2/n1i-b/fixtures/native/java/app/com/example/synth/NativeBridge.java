package com.example.synth;

public class NativeBridge {
    public native void nativeRegistered(int a, String s);    // only strings + JNI_OnLoad: candidate only
}
