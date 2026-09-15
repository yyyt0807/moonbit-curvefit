///|
test "projected steps preserve fixed parameters and scale" {
  let p = [
    parameter("a", 2.0, fixed=true),
    parameter("b", 3.0, lower=0.0, upper=4.0, scale=2.0),
  ]
  assert_eq(active_indices(p), [1])
  let (v, s) = apply_step([2.0, 3.0], p, [1], [9.0])
  assert_eq(v, [2.0, 4.0])
  assert_eq(s, [0.5])
  assert_eq(projected_gradient([1.0], [2.0, 0.0], p, [1]), [0.0])
  assert_eq(projected_gradient([-1.0], [2.0, 0.0], p, [1]), [-1.0])
}
