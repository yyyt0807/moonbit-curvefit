# Initial-review rejection response

Review feedback received 2026-09-17: “项目对于现有生态的拓展功能的价值不明显；申报书中举出的应用场景也未体现广泛的应用需求。” This document records engineering changes, not a claim that the organizer has accepted the resubmission.

## Root cause

The 0.1 proposal presented three variants of one domain—calibration/kinetics/outlier curve fitting—and described differences from nearby packages mostly as an algorithm feature list. Although the low-level `solve` already accepted arbitrary residual vectors, there was no domain-facing contract, no per-term provenance, and no executable proof that another MoonBit forward model could reuse it. The reviewer therefore had little evidence of either an ecosystem seam or broad demand.

## Functional change, not wording only

Version 0.2 adds `ResidualTerm`, `TermDiagnostic`, `ResidualProblemResult`, `residual_term` and `solve_terms`:

- domain packages express each observation/equation as a stable named scalar residual using only core arrays;
- each term carries positive precision and an optional physical gradient;
- analytic Jacobian use is all-or-nothing; any missing gradient selects complete scale-aware numerical differentiation;
- parameter bounds, fixing/scaling, robust objectives, budgets, QR rank and convergence are reused from the existing hardened solver;
- results preserve raw/weighted residual and robust objective contribution for every name, allowing the domain package to trace a poor fit to its own anchor/frequency/sample;
- invalid/duplicate names, weights, callback values and gradient shapes fail explicitly.

This moves the public abstraction from “choose a built-in curve” to “wrap any small dense forward/inverse problem.” Curve models, CSV and reports remain backward-compatible upper layers.

## Ecosystem value made concrete

`owl_mbt` covers ndarray/scientific calculation and generic first-order optimization; `moon-certified` includes linear/polynomial fitting and linear diagnostics. MoonCurveFit now provides a narrower residual-specialized layer those descriptions do not supply: bounded Gauss–Newton/LM structure, robust observation loss and identifiability-aware diagnostics. It uses core arrays, so a consumer does not need to adopt another matrix representation.

Current MoonBit also has forward-domain packages such as `hsy-bit/moonbit-circuit-solver` and `weidekais/moonbit-adsorption`. No dependency, endorsement or completed integration is claimed. They illustrate a real architectural need: forward packages evaluate outputs for known parameters; `solve_terms` is the reusable inverse layer for estimating parameters from observations. The independent RC example demonstrates this adapter pattern without copying their code.

## Broader executable demand

`examples/ecosystem` is included in three CI backends and proves three structurally different problem classes:

1. simultaneous geometric equations—range-based localization for IoT, robotics and games;
2. inverse use of a forward model—frequency-response parameter identification for simulation/digital-twin workflows;
3. bounded operational telemetry modeling—service capacity and latency estimation for performance engineering.

These are not merely renamed x/y datasets: the first is geometry with multiple equations, the second wraps a simulator formula with analytic gradients, and the third enforces a domain capacity bound with numerical derivatives. Together they demonstrate the common reusable need: estimate a few constrained parameters from redundant/noisy evidence on Native, JS or wasm-gc.

## Verification plan

Local evidence before push: 90 tests pass on wasm/wasm-gc/JS/Native, and all three new scenarios recover their synthetic truth on Native/JS/wasm-gc. After push, the exact 0.2 commit must pass Ubuntu/Windows/macOS CI and the version must be installed from mooncakes in a clean consumer before this response is marked complete.

## Remaining limits

This change does not make the solver sparse, global, formally verified or suitable for unlimited data. It does not prove demand from named projects or claim production accuracy for every domain. Real integrations remain future downstream work, and model validity/units/acceptance thresholds remain the consumer's responsibility. The applicant must personally rewrite the one-page proposal under the September “人工撰写” rule.
