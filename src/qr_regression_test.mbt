///|
test "QR input arrays remain isolated" {
  let matrix = [[1.0, 0.0], [1.0, 1.0], [1.0, 2.0]]
  let rhs = [1.0, 3.0, 5.0]
  let q = qr_factor(matrix, rhs).unwrap()
  assert_eq(matrix[1][1], 1.0)
  assert_eq(rhs[2], 5.0)
  matrix[0][0] = 90.0
  rhs[0] = 100.0
  let solution = q.solve().unwrap()
  assert_true((solution[0] - 1.0).abs() < 1.0e-12)
  assert_true((solution[1] - 2.0).abs() < 1.0e-12)
}

///|
test "QR rank tolerance has a relative meaning" {
  let matrix = [[1.0, 0.0], [0.0, 1.0e-8], [0.0, 0.0]]
  let loose = qr_factor(matrix, [1.0, 2.0e-8, 0.0], tolerance=1.0e-6).unwrap()
  let strict = qr_factor(matrix, [1.0, 2.0e-8, 0.0], tolerance=1.0e-10).unwrap()
  assert_eq(loose.rank, 1)
  assert_eq(strict.rank, 2)
  assert_true((strict.solve().unwrap()[1] - 2.0).abs() < 1.0e-12)
  assert_true(loose.inverse_gram() is None)
}

///|
test "QR inverse Gram respects pivoted physical coordinates" {
  let a = [[1.0, 10.0], [1.0, 20.0], [1.0, 30.0], [1.0, 40.0]]
  let q = qr_factor(a, [1.0, 1.0, 1.0, 1.0]).unwrap()
  assert_eq(q.permutation[0], 1)
  let covariance = q.inverse_gram().unwrap()
  for i = 0; i < 2; i = i + 1 {
    for j = 0; j < 2; j = j + 1 {
      let mut product = 0.0
      for k = 0; k < 2; k = k + 1 {
        let mut gram = 0.0
        for row in a {
          gram = gram + row[i] * row[k]
        }
        product = product + gram * covariance[k][j]
      }
      let expected = if i == j { 1.0 } else { 0.0 }
      assert_true((product - expected).abs() < 1.0e-11)
    }
  }
}

///|
test "QR handles very small and large common units" {
  for scale in [1.0e-120, 1.0e120] {
    let a = [[scale, 0.0], [scale, scale], [scale, 2.0 * scale]]
    let q = qr_factor(a, [2.0 * scale, 5.0 * scale, 8.0 * scale]).unwrap()
    let x = q.solve().unwrap()
    assert_eq(q.rank, 2)
    assert_true((x[0] - 2.0).abs() < 1.0e-12)
    assert_true((x[1] - 3.0).abs() < 1.0e-12)
  }
}

///|
test "QR rejects ragged nonfinite and invalid tolerance inputs" {
  assert_true(qr_factor([], []) is Err(_))
  assert_true(qr_factor([[1.0], [1.0, 2.0]], [1.0, 2.0]) is Err(_))
  assert_true(qr_factor([[1.0]], [1.0 / 0.0]) is Err(_))
  assert_true(qr_factor([[0.0 / 0.0]], [1.0]) is Err(_))
  for tolerance in [0.0, -1.0, 1.0, 2.0, 0.0 / 0.0] {
    assert_true(qr_factor([[1.0]], [1.0], tolerance~) is Err(_))
  }
}

///|
test "QR solves generated noisy systems with small normal residual" {
  for columns = 1; columns <= 8; columns = columns + 1 {
    let rows = 4 * columns + 3
    let a = Array::makei(rows, fn(i) {
      Array::makei(columns, fn(j) {
        let phase = (i + 1).to_double() * (j + 1).to_double()
        @math.sin(phase) + (if i == j { 2.0 } else { 0.0 })
      })
    })
    let truth = Array::makei(columns, fn(j) { j.to_double() - 2.5 })
    let rhs = Array::makei(rows, fn(i) {
      let mut value = 0.0
      for j = 0; j < columns; j = j + 1 {
        value = value + a[i][j] * truth[j]
      }
      value + 0.01 * @math.cos(i.to_double())
    })
    let q = qr_factor(a, rhs).unwrap()
    let x = q.solve().unwrap()
    assert_eq(q.rank, columns)
    for j = 0; j < columns; j = j + 1 {
      let mut gradient = 0.0
      for i = 0; i < rows; i = i + 1 {
        let mut prediction = 0.0
        for k = 0; k < columns; k = k + 1 {
          prediction = prediction + a[i][k] * x[k]
        }
        gradient = gradient + a[i][j] * (prediction - rhs[i])
      }
      assert_true(gradient.abs() < 1.0e-10)
    }
  }
}
