use jni::objects::JObject;
use jni::sys::jstring;
use jni::JNIEnv;
use sable_calculator_core::{BinaryOperation, ExactNumber};

fn qualification() -> String {
    let left = ExactNumber::parse_decimal("0.1");
    let right = ExactNumber::parse_decimal("0.2");

    match (left, right) {
        (Ok(left), Ok(right)) => match left.apply(BinaryOperation::Add, right) {
            Ok(result) if result.numerator() == 3 && result.denominator() == 10 => {
                "PASS:calculator-core:3/10".to_owned()
            }
            Ok(result) => format!(
                "FAIL:calculator-core:{}/{}",
                result.numerator(),
                result.denominator()
            ),
            Err(error) => format!("FAIL:calculator-core:{error:?}"),
        },
        _ => "FAIL:calculator-core:parse".to_owned(),
    }
}

#[allow(non_snake_case)]
#[no_mangle]
pub extern "system" fn Java_org_sableos_calculator_NativeBridge_selfTest(
    env: JNIEnv<'_>,
    _this: JObject<'_>,
) -> jstring {
    match env.new_string(qualification()) {
        Ok(value) => value.into_raw(),
        Err(_) => core::ptr::null_mut(),
    }
}
