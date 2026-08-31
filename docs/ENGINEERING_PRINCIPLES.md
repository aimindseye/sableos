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

Prove the effective security property, not merely the absence of one literal policy rule:

- no battery sysfs access;
- service discovery is understood from effective compiled/runtime policy, including attribute grants;
- unauthorized clients cannot transact with or use privileged Binder APIs;
- no policy widening;
- no daemon restart during physical transition;
- no manual slot-success marking;
- no unexpected image delta.

S1.7 is the reference correction: Android 14 shell may discover the Sable power service through platform attribute policy while Binder `call` to `oxynoded` remains denied. Discovery and transaction authority are different properties.

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
- direct-rule service-manager audit -> effective attribute-aware authorization audit;
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

## 13. Renderer Choice Does Not Define OS Privilege

A Rust renderer, GPU backend, launcher or SystemUI replacement candidate does not gain direct hardware/system authority by virtue of being user-facing.

Keep Sable application and interaction semantics above a renderer adapter boundary, and keep privileged operations behind typed Sable services. Qualify touch, keyboard, IME, accessibility, lifecycle, dependency and supply-chain behavior before replacing mature Android presentation components.
