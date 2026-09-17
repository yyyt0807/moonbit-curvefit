# Topic selection and ecosystem comparison

Research performed September 15–16, 2026. Registry searches for curvefit, nonlinear least squares, Levenberg–Marquardt, regression, fitting and related terms were combined with selected upstream README/API inspection. Search results are not proof that every published package has been exhaustively examined.

## Relevant neighbors

- [walkzzz/owl_mbt](https://mooncakes.io/docs/walkzzz/owl_mbt), upstream [toadium/owl-mbt](https://github.com/toadium/owl-mbt), MIT: broad pure-MoonBit scientific facilities including ndarray/linear algebra, autodiff and generic minimize_fun optimization with learning-rate/momentum/batch/regularization configuration. Numerical primitives overlap; a dedicated bounded nonlinear-residual LM plus robust uncertainty/report workflow was not found in the inspected API.
- [Juwan-Hwang/moon-certified](https://mooncakes.io/docs/Juwan-Hwang/moon-certified), upstream [repository](https://github.com/Juwan-Hwang/moon-certified), Apache-2.0: broad algorithms/statistics. Inspected math/least_squares API offers linear_fit/polynomial_fit using normal equations; stats/regression_diagnostics provides linear regression diagnostics. Those overlap with elementary models/statistics here, but not the central nonlinear residual solver.
- Other scientific/optimization packages found during keyword review remain possible partial overlaps. Package names alone cannot determine equivalent functionality.

MoonCurveFit's original contribution is a focused reusable nonlinear residual API with named weighted terms, parameter bounds/fixing/scales, linear/Huber/SoftL1/Cauchy objectives, analytic/numerical gradients, explicit budget/termination handling, pivoted-QR rank and restricted uncertainty, plus strict request/report tooling across backends. It is not merely a renamed linear regression library or a catalogue of preset curves.

The 0.2 recheck also found domain forward-model packages such as `hsy-bit/moonbit-circuit-solver` and `weidekais/moonbit-adsorption`. They are neither dependencies nor claimed integrations. Their existence makes the missing ecosystem layer more concrete: forward simulators calculate outputs for known parameters, whereas a residual optimizer estimates unknown parameters from redundant observations. `examples/ecosystem` demonstrates that adapter boundary with an RC response without copying either project.

The applicant's local portfolio was inspected read-only: MoonBDD, MoonExternalSort, MoonHttpCache, MoonIPFIX, MoonLab, MoonMIME, MoonMVT, MoonOCL (OCI implementation), MoonTusCore. Their principal topics differ from dense numerical curve fitting. No code from those implementations was reused.

## Evidence and limits

Local commands included moon search curvefit (no result), moon search owl_mbt and moon search moon-certified; repository README/tree and selected public API signatures were inspected through GitHub's API. No upstream numerical source was transplanted. See third-party notes for license/provenance.

Conclusion: the defensible ecosystem boundary is portable parameter estimation around MoonBit forward models, not only curve fitting. **Absolute “not similar to any package in any way” cannot be established**: shared QR, elementary fits and statistics are unavoidable. Final originality/topic admission is the contest organizer's decision.
