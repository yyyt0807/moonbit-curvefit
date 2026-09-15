# Provenance and references

- Original implementation, AI-assisted under applicant review; no third-party source code or fixture corpus is copied.
- Algorithm references: standard Householder QR, damped Gauss–Newton, Levenberg–Marquardt, finite differences and M-estimation. Public API descriptions consulted: https://docs.scipy.org/doc/scipy/reference/generated/scipy.optimize.least_squares.html (SciPy, BSD-3-Clause); https://github.com/ceres-solver/ceres-solver (Apache-2.0).
- Direct runtime dependency: bundled `moonbitlang/core`, Apache-2.0. No external numerical runtime dependency.
- All sample data and tests are independently constructed from stated mathematical formulas, not patient data or proprietary measurements.
- The applicant must review attribution, numerical limitations and license suitability before publication.
