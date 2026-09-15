///|
/// Narrow numeric CSV records; quoted numbers supported, embedded newlines excluded.
fn csv_fields(line : String) -> Result[Array[String], FitError] {
  let chars = line.to_array()
  let fields : Array[String] = []
  let field = StringBuilder()
  let mut quoted = false
  let mut closed = false
  let mut i = 0
  while i < chars.length() {
    let ch = chars[i]
    if quoted {
      if ch == '"' {
        if i + 1 < chars.length() && chars[i + 1] == '"' {
          field.write_char('"')
          i = i + 1
        } else {
          quoted = false
          closed = true
        }
      } else {
        field.write_char(ch)
      }
    } else if ch == ',' {
      fields.push(field.to_string().trim().to_owned())
      field.reset()
      closed = false
    } else if ch == '"' {
      if closed || !field.to_string().trim().is_empty() {
        return Err(InvalidData("quote inside unquoted CSV field"))
      }
      field.reset()
      quoted = true
    } else {
      if closed && ch != ' ' && ch != '\t' && ch != '\r' {
        return Err(InvalidData("characters after closing CSV quote"))
      }
      field.write_char(ch)
    }
    i = i + 1
  }
  if quoted {
    return Err(InvalidData("unclosed CSV quote or embedded newline"))
  }
  fields.push(field.to_string().trim().to_owned())
  Ok(fields)
}

///|
pub fn parse_number(value : String) -> Result[Double, FitError] {
  let value = value.trim()
  if value.is_empty() {
    return Err(InvalidData("missing numeric value"))
  }
  try {
    let number = @string.parse_double(value)
    if finite(number) {
      Ok(number)
    } else {
      Err(InvalidData("nonfinite numeric value"))
    }
  } catch {
    _ => Err(InvalidData("invalid numeric value: " + value.to_owned()))
  }
}

///|
/// Exact schema: x,y or x,y,weight in any order. Precision, not stddev, is weight.
pub fn parse_csv(text : String) -> Result[Array[Observation], FitError] {
  if text.length() > 32000000 {
    return Err(InvalidData("CSV text exceeds 32 million code units"))
  }
  let rows : Array[Observation] = []
  let mut header : Array[String]? = None
  let mut x_column = -1
  let mut y_column = -1
  let mut weight_column = -1
  let mut line_number = 0
  for line in text.split("\n") {
    line_number = line_number + 1
    if line.trim().is_empty() {
      continue
    }
    let fields = match csv_fields(line.to_owned()) {
      Ok(v) => v
      Err(_) =>
        return Err(
          InvalidData("malformed CSV at line " + line_number.to_string()),
        )
    }
    if header is None {
      if fields.length() < 2 || fields.length() > 3 {
        return Err(InvalidData("expected x,y[,weight] CSV header"))
      }
      for i = 0; i < fields.length(); i = i + 1 {
        match fields[i] {
          "x" =>
            if x_column != -1 {
              return Err(InvalidData("duplicate x column"))
            } else {
              x_column = i
            }
          "y" =>
            if y_column != -1 {
              return Err(InvalidData("duplicate y column"))
            } else {
              y_column = i
            }
          "weight" =>
            if weight_column != -1 {
              return Err(InvalidData("duplicate weight column"))
            } else {
              weight_column = i
            }
          _ => return Err(InvalidData("unknown CSV column: " + fields[i]))
        }
      }
      if x_column < 0 || y_column < 0 {
        return Err(InvalidData("CSV needs both x and y columns"))
      }
      header = Some(fields)
      continue
    }
    if fields.length() != header.unwrap().length() {
      return Err(
        InvalidData(
          "CSV column count differs at line " + line_number.to_string(),
        ),
      )
    }
    let x = match parse_number(fields[x_column]) {
      Ok(v) => v
      Err(_) =>
        return Err(InvalidData("invalid x at line " + line_number.to_string()))
    }
    let y = match parse_number(fields[y_column]) {
      Ok(v) => v
      Err(_) =>
        return Err(InvalidData("invalid y at line " + line_number.to_string()))
    }
    let weight = if weight_column < 0 {
      1.0
    } else {
      match parse_number(fields[weight_column]) {
        Ok(v) => v
        Err(_) =>
          return Err(
            InvalidData("invalid weight at line " + line_number.to_string()),
          )
      }
    }
    if weight <= 0.0 {
      return Err(
        InvalidData("nonpositive weight at line " + line_number.to_string()),
      )
    }
    rows.push(observation(x, y, weight~))
    if rows.length() > 1000000 {
      return Err(InvalidData("too many CSV observations"))
    }
  }
  match validate_observations(rows) {
    Ok(_) => Ok(rows)
    Err(e) => Err(e)
  }
}

///|
pub fn observations_csv(data : Array[Observation]) -> Result[String, FitError] {
  match validate_observations(data) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let out = StringBuilder()
  out.write_string("x,y,weight\n")
  for o in data {
    out.write_string("\{o.x},\{o.y},\{o.weight}\n")
  }
  Ok(out.to_string())
}
