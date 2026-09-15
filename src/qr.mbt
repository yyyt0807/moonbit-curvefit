///|
/// R and permutation describe A[:, permutation] = Q R.
pub(all) struct QR {
  r : Array[Array[Double]]
  qt_rhs : Array[Double]
  permutation : Array[Int]
  rank : Int
  condition_proxy : Double?
} derive(Debug)

///|
/// Pivoted Householder factorization of a tall dense matrix.
pub fn qr_factor(
  matrix : Array[Array[Double]],
  rhs : Array[Double],
  tolerance? : Double = 1.0e-10,
) -> Result[QR, FitError] {
  let (m, n) = match matrix_shape(matrix) {
    Ok(shape) => shape
    Err(e) => return Err(e)
  }
  if m < n ||
    n > 64 ||
    rhs.length() != m ||
    !finite(tolerance) ||
    tolerance <= 0.0 ||
    tolerance >= 1.0 {
    return Err(
      InvalidData(
        "QR requires m >= n, n <= 64, matching RHS and relative tolerance in (0,1)",
      ),
    )
  }
  for value in rhs {
    if !finite(value) {
      return Err(InvalidData("nonfinite QR RHS"))
    }
  }
  let a = matrix.map(fn(row) { row.copy() })
  let b = rhs.copy()
  let perm = Array::makei(n, fn(i) { i })
  for k = 0; k < n; k = k + 1 {
    let mut pivot = k
    let mut best = -1.0
    for j = k; j < n; j = j + 1 {
      let tail = Array::makei(m - k, fn(i) { a[i + k][j] })
      let length = norm2(tail)
      if length > best {
        best = length
        pivot = j
      }
    }
    if pivot != k {
      for i = 0; i < m; i = i + 1 {
        let temp = a[i][k]
        a[i][k] = a[i][pivot]
        a[i][pivot] = temp
      }
      let temp = perm[k]
      perm[k] = perm[pivot]
      perm[pivot] = temp
    }
    let tail = Array::makei(m - k, fn(i) { a[k + i][k] })
    let length = norm2(tail)
    if length == 0.0 {
      continue
    }
    if !finite(length) {
      return Err(InvalidData("QR norm overflow"))
    }
    let sign = if a[k][k] >= 0.0 { 1.0 } else { -1.0 }
    let v = tail.map(fn(x) { x / length })
    v[0] = v[0] + sign
    let vv = match dot(v, v) {
      Ok(x) => x
      Err(e) => return Err(e)
    }
    let beta = 2.0 / vv
    for j = k; j < n; j = j + 1 {
      let column = Array::makei(m - k, fn(i) { a[k + i][j] })
      let projection = match dot(v, column) {
        Ok(x) => beta * x
        Err(e) => return Err(e)
      }
      for i = k; i < m; i = i + 1 {
        a[i][j] = a[i][j] - projection * v[i - k]
      }
    }
    let tail_b = Array::makei(m - k, fn(i) { b[k + i] })
    let projection = match dot(v, tail_b) {
      Ok(x) => beta * x
      Err(e) => return Err(e)
    }
    for i = k; i < m; i = i + 1 {
      b[i] = b[i] - projection * v[i - k]
    }
    a[k][k] = -sign * length
    for i = k + 1; i < m; i = i + 1 {
      a[i][k] = 0.0
    }
  }
  let r = Array::makei(n, fn(i) {
    Array::makei(n, fn(j) { if j >= i { a[i][j] } else { 0.0 } })
  })
  let reference = r[0][0].abs()
  let mut rank = 0
  for k = 0; k < n; k = k + 1 {
    if r[k][k].abs() > tolerance * reference && r[k][k] != 0.0 {
      rank = rank + 1
    } else {
      break
    }
  }
  let condition = if rank == n {
    let ratio = reference / r[n - 1][n - 1].abs()
    if finite(ratio) {
      Some(ratio)
    } else {
      None
    }
  } else {
    None
  }
  Ok({ r, qt_rhs: b, permutation: perm, rank, condition_proxy: condition, })
}

///|
/// Truncated pivoted solution; rank-deficient covariance is never fabricated.
pub fn QR::solve(self : QR) -> Result[Array[Double], FitError] {
  let n = self.permutation.length()
  let z = Array::make(n, 0.0)
  for i = self.rank - 1; i >= 0; i = i - 1 {
    let mut value = self.qt_rhs[i]
    for j = i + 1; j < self.rank; j = j + 1 {
      value = value - self.r[i][j] * z[j]
    }
    z[i] = value / self.r[i][i]
    if !finite(z[i]) {
      return Err(InvalidData("QR back substitution overflow"))
    }
  }
  let out = Array::make(n, 0.0)
  for i = 0; i < n; i = i + 1 {
    out[self.permutation[i]] = z[i]
  }
  Ok(out)
}

///|
/// Inverse of A' A via R, avoiding a second normal-equations factorization.
pub fn QR::inverse_gram(self : QR) -> Array[Array[Double]]? {
  let n = self.permutation.length()
  if self.rank != n {
    return None
  }
  let inv = zeros(n, n)
  for column = 0; column < n; column = column + 1 {
    for i = n - 1; i >= 0; i = i - 1 {
      let mut value = if i == column { 1.0 } else { 0.0 }
      for j = i + 1; j < n; j = j + 1 {
        value = value - self.r[i][j] * inv[j][column]
      }
      inv[i][column] = value / self.r[i][i]
    }
  }
  let out = zeros(n, n)
  for i = 0; i < n; i = i + 1 {
    for j = 0; j < n; j = j + 1 {
      let value = match dot(inv[i], inv[j]) {
        Ok(v) => v
        Err(_) => return None
      }
      out[self.permutation[i]][self.permutation[j]] = value
    }
  }
  Some(out)
}
