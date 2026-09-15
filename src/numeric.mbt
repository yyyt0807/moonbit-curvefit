///|
/// Scaled sum of squares prevents overflow in the intermediate squares.
pub fn norm2(values : Array[Double]) -> Double {
  let mut scale = 0.0
  let mut sum = 1.0
  for x in values {
    let a = x.abs()
    if a != 0.0 {
      if scale < a {
        let ratio = scale / a
        sum = 1.0 + sum * ratio * ratio
        scale = a
      } else {
        let ratio = a / scale
        sum = sum + ratio * ratio
      }
    }
  }
  if scale == 0.0 {
    0.0
  } else {
    scale * sum.sqrt()
  }
}

///|
pub fn norm_inf(values : Array[Double]) -> Double {
  let mut largest = 0.0
  for x in values {
    if x.abs() > largest {
      largest = x.abs()
    }
  }
  largest
}

///|
/// Neumaier compensated summation, useful for cancellation-heavy residuals.
pub fn compensated_sum(values : Array[Double]) -> Double {
  let mut sum = 0.0
  let mut correction = 0.0
  for x in values {
    let total = sum + x
    let increment = if sum.abs() >= x.abs() {
      sum - total + x
    } else {
      x - total + sum
    }
    correction = correction + increment
    sum = total
  }
  sum + correction
}

///|
pub fn dot(a : Array[Double], b : Array[Double]) -> Result[Double, FitError] {
  if a.length() != b.length() {
    return Err(InvalidData("dot product dimensions differ"))
  }
  let terms = Array::makei(a.length(), fn(i) { a[i] * b[i] })
  let value = compensated_sum(terms)
  if finite(value) {
    Ok(value)
  } else {
    Err(InvalidData("dot product overflow"))
  }
}

///|
pub fn zeros(rows : Int, columns : Int) -> Array[Array[Double]] {
  Array::makei(rows, fn(_) { Array::make(columns, 0.0) })
}

///|
pub fn matrix_shape(
  matrix : Array[Array[Double]],
) -> Result[(Int, Int), FitError] {
  if matrix.is_empty() || matrix[0].is_empty() {
    return Err(InvalidData("empty matrix"))
  }
  let n = matrix[0].length()
  for row in matrix {
    if row.length() != n {
      return Err(InvalidData("ragged matrix"))
    }
    for value in row {
      if !finite(value) {
        return Err(InvalidData("nonfinite matrix entry"))
      }
    }
  }
  Ok((matrix.length(), n))
}

///|
pub fn transpose(
  matrix : Array[Array[Double]],
) -> Result[Array[Array[Double]], FitError] {
  let (m, n) = match matrix_shape(matrix) {
    Ok(shape) => shape
    Err(e) => return Err(e)
  }
  Ok(Array::makei(n, fn(j) { Array::makei(m, fn(i) { matrix[i][j] }) }))
}

///|
pub fn matvec(
  matrix : Array[Array[Double]],
  vector : Array[Double],
) -> Result[Array[Double], FitError] {
  let (_, n) = match matrix_shape(matrix) {
    Ok(shape) => shape
    Err(e) => return Err(e)
  }
  if vector.length() != n {
    return Err(InvalidData("matrix-vector dimensions differ"))
  }
  let out : Array[Double] = []
  for row in matrix {
    match dot(row, vector) {
      Ok(v) => out.push(v)
      Err(e) => return Err(e)
    }
  }
  Ok(out)
}
