///|
test "nonfinite norms cannot masquerade as zero gradients" {
  assert_true(!finite(norm_inf([0.0 / 0.0])))
  assert_true(!finite(norm2([0.0 / 0.0])))
  assert_true(!finite(norm_inf([1.0 / 0.0])))
  let result = solve([parameter("a", 0.0)], fn(_) { [1.0e100, 1.0e100] }, jacobian=fn(
    _,
  ) {
    [[1.0e250], [1.0e250]]
  })
  assert_true(result is Err(_))
}

///|
test "statistics rejects overflow instead of exporting infinite SSE" {
  assert_true(statistics([0.0, 0.0], [1.0e154, 1.0e154], 1) is Err(_))
  let tiny = statistics([1.0e-160, 2.0e-160], [0.0, 0.0], 1).unwrap()
  assert_true(finite(tiny.aic.unwrap()))
}
