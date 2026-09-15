///|
test "numerical Jacobian handles fixed parameters and one-sided bounds" {
  let j = numerical_jacobian(fn(p) { [p[0] * p[0] + p[1], p[0] * 3.0] }, [
    parameter("a", 2.0),
    parameter("b", 1.0, fixed=true),
  ]).unwrap()
  assert_true((j[0][0] - 4.0).abs() < 1.0e-8)
  assert_eq(j[0][1], 0.0)
  let bounded = numerical_jacobian(fn(p) { [p[0] * 3.0] }, [
    parameter("a", 0.0, lower=0.0),
  ]).unwrap()
  assert_true((bounded[0][0] - 3.0).abs() < 1.0e-12)
}

///|
test "numerical Jacobian rejects unstable residual count" {
  assert_true(
    numerical_jacobian(fn(p) { if p[0] > 0.0 { [1.0] } else { [1.0, 2.0] } }, [
      parameter("x", 0.0),
    ])
    is Err(_),
  )
}
