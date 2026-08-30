# SableOS Engineering Principles

## 1. Measure Before Tuning

Power, thermal, scheduler, modem, memory and lifecycle changes require device evidence.

Record baseline, intervention, workload, before/after metrics, regressions, and rollback condition.

Useful metrics:

- CPU frequency residency;
- wakeups/interrupts;
- power/current proxy;
- temperature;
- memory pressure;
- interaction latency;
- app launch time.

A plausible explanation is not evidence.

## 2. Fix Architecture, Not Test Timing

S1.6 established this directly: polling missed a real power transition across suspend, so the architecture changed to callbacks instead of extending test timing or adding a wakelock.

## 3. Keep Device Quirks Below Stable Contracts

Examples:

- bramble may classify a reconnect as AC;
- Health may emit `Battery -> Unknown -> AC`;
- vendor image is immutable.

These belong below generic UI contracts.

## 4. Privilege Follows Responsibility

The compositor is not automatically the power manager.
The status bar is not automatically a Health client.
A network toggle does not justify `CAP_NET_ADMIN` in the UI.

## 5. Prefer Typed Interfaces

Prefer `getLatestState()` over generic data bags.
Prefer `setFeatureEnabled(bool)` over shelling out.

## 6. Negative Tests Are First-class

Prove what must not happen:

- no battery sysfs access;
- no unauthorized Binder `find`;
- no policy widening;
- no daemon restart during physical transition;
- no manual slot-success marking;
- no unexpected image delta.

## 7. Preserve Known-good Recovery

Inactive-slot deployment is mandatory for risky runtime changes. Activation comes last.

## 8. Freeze Contracts Deliberately

Once consumed by UI/services, treat compatibility as a product constraint.

## 9. Separate Product Inspiration From Security Architecture

Borrow UX ideas without borrowing a weaker trust model.

## 10. Document Failed Assumptions

Important reversals belong in project history:

- raw sysfs design -> Health HAL;
- polling -> callback delivery;
- direct reconnect expectation -> valid transient Unknown;
- build failure classification before source repair.

## 11. Bound Output and Tests

Scripts should:

- avoid unbounded recursive searches;
- redirect full build logs;
- print bounded tails;
- preserve pipeline status;
- emit explicit PASS/FAIL;
- never terminate an interactive tmux shell.

## 12. Production Path Is Not a Debug Path

Production correctness must not depend on root, samplers, synthetic battery state, debug CLI probes, or test-only overrides.
