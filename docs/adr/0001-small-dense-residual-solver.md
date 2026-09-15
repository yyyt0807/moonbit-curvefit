# A small dense residual solver, not a scientific computing platform

We expose arbitrary residual and optional Jacobian callbacks, with named parameters, fixed values, bounds and structured outcomes. A scaled projected Levenberg–Marquardt solver using pivoted Householder QR covers small dense calibration and scientific fitting without requiring Python, a C library or a tensor runtime. Sparse optimization, autodiff, ODE integration, formula languages and clinical recommendations are deliberately excluded; changing that boundary would invalidate both the numerical and maintenance budget.
