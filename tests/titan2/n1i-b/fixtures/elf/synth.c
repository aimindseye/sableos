/* Synthetic JNI-shaped shared library for N1I-B ELF reader tests. Not derived from any OEM code. */
typedef void *JNIEnv;
typedef void *JavaVM;
typedef void *jobject;
typedef int jint;

extern int dep_function(int x);

static const char kClass[] = "com/example/synth/NativeBridge";
static const char kSig[] = "(ILjava/lang/String;)V";
static const char kName[] = "nativeRegistered";
static const char kNoise[] = "not/a class name";

__attribute__((visibility("default"))) jint Java_p_Ops_nativeInstance(JNIEnv *env, jobject thiz, jint x) {
    return x + dep_function(x);
}

__attribute__((visibility("default"))) jobject Java_p_Ops_nativeStatic(JNIEnv *env, jobject cls, jobject s) {
    return s;
}

__attribute__((visibility("default"))) jint Java_com_example_Foo_1Bar_over__ILjava_lang_String_2(JNIEnv *env, jobject cls, jint a, jobject s) {
    return a;
}

__attribute__((visibility("default"))) jint JNI_OnLoad(JavaVM *vm, void *reserved) {
    return (jint)(kClass[0] + kSig[0] + kName[0] + kNoise[0]);
}

__attribute__((visibility("hidden"))) int hidden_helper(void) { return 7; }

__attribute__((weak, visibility("default"))) int weak_export(void) { return hidden_helper(); }
