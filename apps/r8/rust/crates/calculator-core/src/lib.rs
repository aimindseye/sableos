//! Deterministic, offline calculator domain for Sable Calculator.
//! Values use six fixed decimal places; no binary floating point is used.

use core::fmt;

const SCALE: i128 = 1_000_000;

#[derive(Clone, Copy, Debug, Eq, PartialEq, Ord, PartialOrd)]
pub struct Decimal(i128);

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum CalcError {
    Empty,
    InvalidNumber,
    UnexpectedToken,
    DivisionByZero,
    Overflow,
}

impl Decimal {
    pub const ZERO: Self = Self(0);

    #[must_use]
    pub const fn raw(self) -> i128 {
        self.0
    }

    pub fn parse(text: &str) -> Result<Self, CalcError> {
        let text = text.trim();
        if text.is_empty() {
            return Err(CalcError::InvalidNumber);
        }
        let (negative, digits) = match text.as_bytes()[0] {
            b'+' => (false, &text[1..]),
            b'-' => (true, &text[1..]),
            _ => (false, text),
        };
        if digits.is_empty() {
            return Err(CalcError::InvalidNumber);
        }
        let mut split = digits.split('.');
        let whole = split.next().unwrap_or_default();
        let frac = split.next();
        if split.next().is_some() || whole.is_empty() || !whole.bytes().all(|b| b.is_ascii_digit()) {
            return Err(CalcError::InvalidNumber);
        }
        let whole_value = whole.parse::<i128>().map_err(|_| CalcError::Overflow)?;
        let mut value = whole_value.checked_mul(SCALE).ok_or(CalcError::Overflow)?;
        if let Some(frac) = frac {
            if frac.is_empty() || frac.len() > 6 || !frac.bytes().all(|b| b.is_ascii_digit()) {
                return Err(CalcError::InvalidNumber);
            }
            let frac_value = frac.parse::<i128>().map_err(|_| CalcError::InvalidNumber)?;
            let multiplier = 10_i128.pow((6 - frac.len()) as u32);
            value = value
                .checked_add(frac_value.checked_mul(multiplier).ok_or(CalcError::Overflow)?)
                .ok_or(CalcError::Overflow)?;
        }
        if negative {
            value = value.checked_neg().ok_or(CalcError::Overflow)?;
        }
        Ok(Self(value))
    }

    fn checked_add(self, rhs: Self) -> Result<Self, CalcError> {
        self.0.checked_add(rhs.0).map(Self).ok_or(CalcError::Overflow)
    }

    fn checked_sub(self, rhs: Self) -> Result<Self, CalcError> {
        self.0.checked_sub(rhs.0).map(Self).ok_or(CalcError::Overflow)
    }

    fn checked_mul(self, rhs: Self) -> Result<Self, CalcError> {
        let product = self.0.checked_mul(rhs.0).ok_or(CalcError::Overflow)?;
        Ok(Self(div_round(product, SCALE)))
    }

    fn checked_div(self, rhs: Self) -> Result<Self, CalcError> {
        if rhs.0 == 0 {
            return Err(CalcError::DivisionByZero);
        }
        let numerator = self.0.checked_mul(SCALE).ok_or(CalcError::Overflow)?;
        Ok(Self(div_round_signed(numerator, rhs.0)))
    }
}

impl fmt::Display for Decimal {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let negative = self.0 < 0;
        let magnitude = self.0.unsigned_abs();
        let whole = magnitude / SCALE as u128;
        let frac = magnitude % SCALE as u128;
        if negative {
            write!(f, "-")?;
        }
        if frac == 0 {
            return write!(f, "{whole}");
        }
        let mut fractional = format!("{frac:06}");
        while fractional.ends_with('0') {
            fractional.pop();
        }
        write!(f, "{whole}.{fractional}")
    }
}

pub fn evaluate(expression: &str) -> Result<Decimal, CalcError> {
    let mut parser = Parser::new(expression);
    if parser.remaining().trim().is_empty() {
        return Err(CalcError::Empty);
    }
    let result = parser.parse_expression()?;
    parser.skip_ws();
    if parser.pos != parser.input.len() {
        return Err(CalcError::UnexpectedToken);
    }
    Ok(result)
}

struct Parser<'a> {
    input: &'a str,
    pos: usize,
}

impl<'a> Parser<'a> {
    const fn new(input: &'a str) -> Self {
        Self { input, pos: 0 }
    }

    fn remaining(&self) -> &str {
        &self.input[self.pos..]
    }

    fn skip_ws(&mut self) {
        while self.pos < self.input.len() && self.input.as_bytes()[self.pos].is_ascii_whitespace() {
            self.pos += 1;
        }
    }

    fn consume(&mut self, token: u8) -> bool {
        self.skip_ws();
        if self.input.as_bytes().get(self.pos) == Some(&token) {
            self.pos += 1;
            true
        } else {
            false
        }
    }

    fn parse_expression(&mut self) -> Result<Decimal, CalcError> {
        let mut value = self.parse_term()?;
        loop {
            if self.consume(b'+') {
                value = value.checked_add(self.parse_term()?)?;
            } else if self.consume(b'-') {
                value = value.checked_sub(self.parse_term()?)?;
            } else {
                return Ok(value);
            }
        }
    }

    fn parse_term(&mut self) -> Result<Decimal, CalcError> {
        let mut value = self.parse_factor()?;
        loop {
            if self.consume(b'*') {
                value = value.checked_mul(self.parse_factor()?)?;
            } else if self.consume(b'/') {
                value = value.checked_div(self.parse_factor()?)?;
            } else {
                return Ok(value);
            }
        }
    }

    fn parse_factor(&mut self) -> Result<Decimal, CalcError> {
        self.skip_ws();
        if self.consume(b'+') {
            return self.parse_factor();
        }
        if self.consume(b'-') {
            let value = self.parse_factor()?;
            return value.0.checked_neg().map(Decimal).ok_or(CalcError::Overflow);
        }
        if self.consume(b'(') {
            let value = self.parse_expression()?;
            if !self.consume(b')') {
                return Err(CalcError::UnexpectedToken);
            }
            return Ok(value);
        }
        self.parse_number()
    }

    fn parse_number(&mut self) -> Result<Decimal, CalcError> {
        self.skip_ws();
        let start = self.pos;
        let mut seen_digit = false;
        let mut seen_dot = false;
        while let Some(byte) = self.input.as_bytes().get(self.pos).copied() {
            if byte.is_ascii_digit() {
                seen_digit = true;
                self.pos += 1;
            } else if byte == b'.' && !seen_dot {
                seen_dot = true;
                self.pos += 1;
            } else {
                break;
            }
        }
        if !seen_digit {
            return Err(CalcError::UnexpectedToken);
        }
        Decimal::parse(&self.input[start..self.pos])
    }
}

fn div_round(numerator: i128, denominator: i128) -> i128 {
    debug_assert!(denominator > 0);
    if numerator >= 0 {
        (numerator + denominator / 2) / denominator
    } else {
        -((-numerator + denominator / 2) / denominator)
    }
}

fn div_round_signed(numerator: i128, denominator: i128) -> i128 {
    let negative = (numerator < 0) ^ (denominator < 0);
    let n = numerator.unsigned_abs();
    let d = denominator.unsigned_abs();
    let rounded = (n + d / 2) / d;
    if negative { -(rounded as i128) } else { rounded as i128 }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn precedence_and_parentheses() {
        assert_eq!(evaluate("2 + 3 * 4").unwrap().to_string(), "14");
        assert_eq!(evaluate("(2 + 3) * 4").unwrap().to_string(), "20");
    }

    #[test]
    fn decimal_is_fixed_point() {
        assert_eq!(evaluate("0.1 + 0.2").unwrap().to_string(), "0.3");
        assert_eq!(evaluate("5 / 2").unwrap().to_string(), "2.5");
    }

    #[test]
    fn unary_and_error_paths() {
        assert_eq!(evaluate("-(3.5) + 1").unwrap().to_string(), "-2.5");
        assert_eq!(evaluate("1/0"), Err(CalcError::DivisionByZero));
        assert_eq!(evaluate(""), Err(CalcError::Empty));
    }
}
