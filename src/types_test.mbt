///|
test "parameter contract rejects duplicate names and inconsistent bounds" {
  assert_true(validate_parameters([parameter("a", 1.0)]) is Ok(_))
  assert_true(
    validate_parameters([parameter("a", 1.0), parameter("a", 2.0)]) is Err(_),
  )
  assert_true(validate_parameters([parameter("a", 1.0, lower=2.0)]) is Err(_))
  assert_true(
    validate_parameters([parameter("a", 1.0, lower=1.0, upper=1.0)]) is Err(_),
  )
  assert_true(validate_parameters([parameter("a", 1.0, scale=0.0)]) is Err(_))
}

///|
test "options contract and finite classification" {
  assert_true(validate_options(default_options()) is Ok(_))
  assert_true(
    validate_options({ ..default_options(), loss: Huber(0.0), }) is Err(_),
  )
  assert_true(!finite(0.0 / 0.0))
  assert_true(!finite(1.0 / 0.0))
  assert_true(finite(1.0e300))
}
