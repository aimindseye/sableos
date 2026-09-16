use jni::objects::JObject;
use jni::sys::jstring;
use jni::JNIEnv;
use sable_convert_core::{convert_milli, Unit};

fn qualification() -> String {
    match convert_milli(5_000, Unit::Miles, Unit::Kilometers) {
        Ok(8_047) => "PASS:convert-core:8047".to_owned(),
        Ok(value) => format!("FAIL:convert-core:{value}"),
        Err(error) => format!("FAIL:convert-core:{error:?}"),
    }
}

#[allow(non_snake_case)]
#[no_mangle]
pub extern "system" fn Java_org_sableos_convert_NativeBridge_selfTest(
    env: JNIEnv<'_>,
    _this: JObject<'_>,
) -> jstring {
    match env.new_string(qualification()) {
        Ok(value) => value.into_raw(),
        Err(_) => core::ptr::null_mut(),
    }
}
