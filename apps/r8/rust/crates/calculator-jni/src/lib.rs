use jni::objects::{JObject, JString};
use jni::sys::{jint, jstring};
use jni::JNIEnv;
use sable_calculator_core::{ArithmeticError, BinaryOperation, ExactNumber};

fn operation_from_code(code: i32) -> Option<BinaryOperation> {
    match code {
        0 => Some(BinaryOperation::Add),
        1 => Some(BinaryOperation::Subtract),
        2 => Some(BinaryOperation::Multiply),
        3 => Some(BinaryOperation::Divide),
        _ => None,
    }
}

fn arithmetic_error(error: ArithmeticError) -> &'static str {
    match error {
        ArithmeticError::InvalidNumber => "ERR:INVALID_NUMBER",
        ArithmeticError::DivisionByZero => "ERR:DIVIDE_BY_ZERO",
        ArithmeticError::Overflow => "ERR:OVERFLOW",
    }
}

fn apply_binary(left: &str, operation: i32, right: &str) -> String {
    let Some(operation) = operation_from_code(operation) else {
        return "ERR:INVALID_OPERATION".to_owned();
    };

    let left = match ExactNumber::parse_decimal(left) {
        Ok(value) => value,
        Err(error) => return arithmetic_error(error).to_owned(),
    };

    let right = match ExactNumber::parse_decimal(right) {
        Ok(value) => value,
        Err(error) => return arithmetic_error(error).to_owned(),
    };

    match left.apply(operation, right) {
        Ok(value) => format!("OK:{value}"),
        Err(error) => arithmetic_error(error).to_owned(),
    }
}

fn qualification() -> String {
    match apply_binary("0.1", 0, "0.2").as_str() {
        "OK:3/10" => "PASS:calculator-core:3/10".to_owned(),
        result => format!("FAIL:calculator-core:{result}"),
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

#[allow(non_snake_case)]
#[no_mangle]
pub extern "system" fn Java_org_sableos_calculator_NativeBridge_applyBinary(
    mut env: JNIEnv<'_>,
    _this: JObject<'_>,
    left: JString<'_>,
    operation: jint,
    right: JString<'_>,
) -> jstring {
    let left: String = match env.get_string(&left) {
        Ok(value) => value.into(),
        Err(_) => return core::ptr::null_mut(),
    };

    let right: String = match env.get_string(&right) {
        Ok(value) => value.into(),
        Err(_) => return core::ptr::null_mut(),
    };

    match env.new_string(apply_binary(&left, operation, &right)) {
        Ok(value) => value.into_raw(),
        Err(_) => core::ptr::null_mut(),
    }
}

#[cfg(test)]
mod tests {
    use super::apply_binary;

    #[test]
    fn product_protocol_preserves_exact_arithmetic() {
        assert_eq!(apply_binary("0.1", 0, "0.2"), "OK:3/10");
        assert_eq!(apply_binary("1", 3, "4"), "OK:1/4");
        assert_eq!(apply_binary("-2.50", 0, "1"), "OK:-3/2");
    }

    #[test]
    fn product_protocol_maps_errors() {
        assert_eq!(apply_binary("1", 99, "2"), "ERR:INVALID_OPERATION");
        assert_eq!(apply_binary("invalid", 0, "2"), "ERR:INVALID_NUMBER");
        assert_eq!(apply_binary("1", 3, "0"), "ERR:DIVIDE_BY_ZERO");
        assert_eq!(
            apply_binary("170141183460469231731687303715884105728", 0, "1",),
            "ERR:OVERFLOW",
        );
    }
}
