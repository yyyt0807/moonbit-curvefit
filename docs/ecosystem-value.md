# Ecosystem extension: a residual optimization seam

MoonCurveFit 0.2 is not limited to an x/y curve catalogue. Its reusable center is a small-dense residual optimizer: a caller describes unknown parameters and named scalar discrepancies, while the library owns bounds, scaling, weighting, robust loss, derivative fallback, evaluation budgets, convergence and rank diagnostics. This is a concrete seam between MoonBit **domain packages** and **numerical optimization**.

## What other packages would otherwise rebuild

A domain package commonly has a forward calculation `prediction(parameters)`, measured/target values and unknown parameters. Turning that into reliable estimation requires more than a loop around a generic minimizer: residual-specific Gauss–Newton curvature, physical scaling, feasible bound probes, rank/identifiability reporting, robust outlier handling and per-observation evidence. `residual_term` / `solve_terms` supplies this policy through core `Array[Double]`, so consumers need no ndarray dependency or numerical FFI.

Each term has a stable name, positive precision and optional physical gradient. If all gradients exist, the solver uses them; if any is absent, it deliberately computes the **whole** Jacobian numerically instead of mixing derivatives silently. The result returns raw/weighted residual and objective contribution per name. This lets an upstream simulator map a suspicious fitted contribution back to its frequency, anchor, sample or constraint.

## Relationship to current packages

- `walkzzz/owl_mbt` is a broad scientific/ndarray and generic first-order optimization ecosystem. MoonCurveFit does not replace it: it supplies a residual-specialized bounded LM path with robust objectives and eligibility-aware diagnostics. Future adapters can translate ndarray data at the boundary; the core stays backend-portable.
- `Juwan-Hwang/moon-certified` provides verified algorithms plus linear/polynomial least squares and linear regression diagnostics. MoonCurveFit extends the available problem class to nonlinear forward models, bounds and outliers. It does not claim formal verification.
- Domain packages such as `hsy-bit/moonbit-circuit-solver` (forward circuit simulation) and `weidekais/moonbit-adsorption` (isotherm/breakthrough calculations) demonstrate that MoonBit already has forward scientific models. They are **not dependencies and have not endorsed this project**. The reusable extension point is that such a model can emit named residual terms to identify parameters from observations without implementing another optimizer. The RC example proves this integration pattern with an independent forward formula.

Registry/API inspection on 2026-09-17 found no separate package offering the same named bounded nonlinear residual workflow. This is evidence of a gap, not an exhaustive uniqueness proof.

## Executable cross-domain proof

`moon run examples/ecosystem --target native` runs three independent uses of the same public API:

1. range-based 2D localization for IoT/robotics/game anchors: three distance equations recover `(4,3)` with analytic gradients;
2. forward-model parameter identification: five frequency-response observations recover RC gain `2` and time constant `0.5`;
3. service capacity planning: six software-telemetry points recover base latency, capacity and queue scale using bounded numerical derivatives.

These are not three renamed curve tables: localization solves simultaneous geometry equations; parameter identification wraps a forward simulator; capacity planning uses operational telemetry. They share a widespread engineering need—recover a small set of constrained parameters from redundant noisy observations—and run unchanged on Native, JavaScript and wasm-gc.

The examples are synthetic and assert known truth. They demonstrate integration mechanics and numerical recovery, not production accuracy for every radio environment, circuit or service. Real consumers remain responsible for model validity, units, data governance and domain-specific acceptance thresholds.
