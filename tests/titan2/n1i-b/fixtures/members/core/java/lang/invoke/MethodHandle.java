package java.lang.invoke;
public abstract class MethodHandle {
  @PolymorphicSignature public final native Object invoke(Object... args) throws Throwable;
  @PolymorphicSignature public final native Object invokeExact(Object... args) throws Throwable;
  @interface PolymorphicSignature {}
}
