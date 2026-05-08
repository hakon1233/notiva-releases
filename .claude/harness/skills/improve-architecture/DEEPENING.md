# Deepening — when ports/adapters are justified

A four-bucket taxonomy. **Read this before proposing any new port,
adapter, or "interface for testability" inside an architecture review.**

The shorter rule: ports are paid for in indirection cost; you only
spend that cost when you actually buy a seam (two adapters, see
`module-map/LANGUAGE.md` rule #3). The taxonomy below is just the
specific guidance per dependency category.

---

## Bucket 1 — In-process

**Examples:** internal functions, classes, modules in the same package,
in-memory state stores, type definitions.

**Rule:** always deepenable directly. **No port.** The "seam" is the
function call itself. Refactoring inside a single process is
re-arranging code, not adding architecture.

If you find yourself wanting a port for an in-process dependency, the
*module* is the wrong shape. Fix that first — split or rename the
underlying module, don't paper over it with indirection.

**Tests:** call the real thing. Pure functions test trivially; class
methods test through the class.

---

## Bucket 2 — Local-substitutable

**Examples:** PGLite for postgres, in-memory FS, fake clock,
in-memory event store, an in-process queue.

**Rule:** swap implementation **internally** at the deepest possible
level. **No port abstraction.** The "substitutability" is a property of
the implementation — the module's interface stays the same.

Instead of `interface DB { … }; class PgDB; class PgliteDB`, use a
single `class DB` whose constructor accepts a connection string; tests
construct it with a PGLite URL, prod constructs it with the real one.
The seam is the URL, not the interface.

**Reason:** an "interface for substitutability" is a Bucket-1 violation
in disguise — you're adding a port to a Bucket-1 (in-process) thing
because you confused testability with extensibility.

**Tests:** the substitution happens at construction time. The interface
under test is identical in production and in test.

---

## Bucket 3 — Remote-but-owned

**Examples:** our PTY server, our gateway, our Supabase project, our
Pulse cluster, our internal API.

**Rule:** **conditional port.** A port + adapter pair is justified
when:
- (a) at least two real adapters are on the way (e.g. local + cloud,
  or v1 + v2 during a migration), AND
- (b) the failure modes (timeout, retry, breaker) need to be encoded
  in the interface.

If only (b) is true and only one adapter exists, centralize the
retry/breaker/timeout in one *internal* module instead of an interface.
That's still leverage; it's just not a seam.

**Tests:** integration tests against the real thing in dev/CI; an
in-memory stub in test only when (a) holds.

---

## Bucket 4 — True external

**Examples:** Stripe, Slack API, Anthropic API, OpenAI API, Twilio,
GitHub API.

**Rule:** **inject a port. Ship a mock adapter.** Required.

The vendor is uncontrollable: rate limits, schema drift, vendor
outages, breaking changes. Isolation pays for itself in:

- Tests that don't burn vendor credits
- Re-tries / breakers / fallover encoded in the interface
- Schema-drift detection at the adapter boundary
- Ability to swap vendors (this is the second adapter that justifies
  the port — even if you don't have it today, the *prospect* of
  swapping is real for true-external dependencies)

**Tests:** mock adapter with realistic failure modes. Integration test
against a sandbox account in CI when feasible.

---

## How to use this taxonomy in a review

When `improve-architecture` Phase 3 grills a candidate that involves an
external dependency:

1. Classify the dependency into a bucket.
2. Apply the bucket's rule.
3. If the candidate proposed a port, check: which bucket is this? If
   1 or 2, reject the port. If 3, ask "two real adapters?". If 4,
   accept.
4. Record the bucket assignment in the candidate's design doc — future
   reviewers can re-use the classification.

---

## Why we reject Ousterhout's depth-as-ratio

The original `Philosophy of Software Design` defines depth as
implementation-lines-per-interface-line. That metric rewards padding
the implementation: a module that does one thing in 5 lines but is
hidden behind a 1-line interface scores well by the ratio, even though
the leverage is zero.

We use **depth-as-leverage** instead — what does the caller get to *not*
think about? — so the deletion test directly measures depth. A module
fails the deletion test exactly when its caller would happily inline
it; that's the same as saying it has no leverage.

---

## Provenance

Adapted from Matt Pocock's `DEEPENING.md` (MIT). Local extensions: the
"central retry/breaker module without a port" pattern in Bucket 3 is
specific to our PTY/gateway architecture; the "schema-drift detection
at the adapter boundary" callout in Bucket 4 maps to our Anthropic /
OpenAI provider auth-state hygiene that surfaced as auditor findings
in 2026-04.
