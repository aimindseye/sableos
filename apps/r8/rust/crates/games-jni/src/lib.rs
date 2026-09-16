use jni::objects::JObject;
use jni::sys::jstring;
use jni::JNIEnv;
use sable_games_core::sudoku::{Board, Error};

fn qualification() -> String {
    let puzzle = "0".repeat(81);

    let result = Board::parse(&puzzle).and_then(|mut board| {
        board.set(0, 0, 5)?;
        match board.set(0, 1, 5) {
            Err(Error::Conflict) => Ok(()),
            Err(error) => Err(error),
            Ok(()) => Err(Error::InvalidPuzzle),
        }
    });

    match result {
        Ok(()) => "PASS:games-core:sudoku-conflict".to_owned(),
        Err(error) => format!("FAIL:games-core:{error:?}"),
    }
}

#[allow(non_snake_case)]
#[no_mangle]
pub extern "system" fn Java_org_sableos_games_NativeBridge_selfTest(
    env: JNIEnv<'_>,
    _this: JObject<'_>,
) -> jstring {
    match env.new_string(qualification()) {
        Ok(value) => value.into_raw(),
        Err(_) => core::ptr::null_mut(),
    }
}
