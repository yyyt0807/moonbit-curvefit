///|
test "loss is symmetric and robust influence shrinks" {
  let losses : Array[Loss] = [Linear, Huber(1.0), SoftL1(1.0), Cauchy(1.0)]
  for loss in losses {
    let (a, w) = loss_value(loss, 10.0)
    let (b, _) = loss_value(loss, -10.0)
    assert_eq(a, b)
    assert_true(w > 0.0 && w <= 1.0)
    assert_true(a <= 50.0)
    assert_eq(loss_value(loss, 0.0), (0.0, 1.0))
  }
}

///|
test "IRLS residual and Jacobian share weights" {
  let (r, j) = robust_linearization(Huber(1.0), [4.0], [[2.0, 6.0]])
  assert_eq(r, [2.0])
  assert_eq(j, [[1.0, 3.0]])
  assert_true(objective(Linear, [1.0e300]) is Err(_))
}
