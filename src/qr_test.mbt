///|
test "QR solves tall regression and unpermutes columns" {
  let a = [[1.0, 0.0], [1.0, 1.0], [1.0, 2.0], [1.0, 3.0]]
  let factor = qr_factor(a, [2.0, 5.0, 8.0, 11.0]).unwrap()
  let x = factor.solve().unwrap()
  assert_true((x[0] - 2.0).abs() < 1.0e-12)
  assert_true((x[1] - 3.0).abs() < 1.0e-12)
  assert_eq(factor.rank, 2)
  let inv = factor.inverse_gram().unwrap()
  assert_true((inv[0][0] - 0.7).abs() < 1.0e-12)
  assert_true((inv[1][1] - 0.2).abs() < 1.0e-12)
}

///|
test "QR rank deficiency is explicit" {
  let q = qr_factor([[1.0, 2.0], [2.0, 4.0], [3.0, 6.0]], [1.0, 2.0, 3.0]).unwrap()
  assert_eq(q.rank, 1)
  assert_eq(q.inverse_gram(), None)
  assert_true(qr_factor([[1.0, 2.0]], [1.0]) is Err(_))
}
