///|
test "scaled norm and compensated cancellation" {
  assert_true((norm2([3.0, 4.0]) - 5.0).abs() < 1.0e-12)
  assert_true(finite(norm2([1.0e300, 1.0e300])))
  assert_eq(compensated_sum([1.0e16, 1.0, -1.0e16]), 1.0)
  assert_eq(norm_inf([-2.0, 1.0]), 2.0)
}

///|
test "matrix shape and independent rows" {
  let m = zeros(2, 3)
  m[0][0] = 8.0
  assert_eq(m[1][0], 0.0)
  assert_true(matrix_shape([[1.0], [2.0, 3.0]]) is Err(_))
  assert_true(dot([1.0], []) is Err(_))
  assert_true(matvec([[1.0, 2.0]], [3.0, 4.0]) is Ok([11.0]))
}
