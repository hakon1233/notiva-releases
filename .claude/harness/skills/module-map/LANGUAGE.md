# Module-Map — vocabulary contract

Every architecture proposal, every worker dispatch, every code review in
this repo MUST use this vocabulary. Substitute words are listed below
and banned: if you reach for one, pause and rephrase using the
canonical term. Reviewers should reject prose that mixes vocabularies
— coherence matters more than personal preference.

The contract exists because architecture conversations between agents
collapse fast when vocabulary drifts. "Should this be a service?" and
"should this be a module?" are not the same question. Forcing one
vocabulary makes worker output reviewable at a glance and makes design
disagreements actually be about design.

This file is owned by the harness. Edit only via PR with a justification
line. Do not adopt new terms without removing or renaming the term being
displaced.

---

## Canonical terms

### Module

The unit of design. Scale-agnostic — a module can be a single function,
a class, a directory, a package, a service. What makes something a
module is that it has an **interface** (below) and a thing on the other
side of it.

A module is named by what it does, in domain verbs. Not by its layer
("util", "helper"), not by its position in a stack ("frontend",
"backend"), not by its file type (".ts file"). The name should answer
"what would I lose if you deleted this?".

### Interface

Everything the caller has to know to use the module correctly. Not just
the type signature. Includes:

- function/method signatures (what most people mean)
- **invariants** the module promises to preserve
- **ordering** constraints (must call A before B)
- **error modes** (what throws, when)
- **config / setup** the caller has to provide
- **performance shape** the caller can rely on (is this O(n)? is it
  cached? does it block on I/O?)

If you change any of these without a migration, you've changed the
interface. Type-signature stability alone is not interface stability.

### Depth

How much **leverage** a module gives its caller relative to how much
the caller has to know. A deep module hides a lot of complexity behind
a small interface; a shallow module is roughly as complex inside as
it is outside.

We **reject the ratio definition** of depth (lines of implementation
divided by lines of interface). It rewards padding the implementation
and is gameable. We define depth as **leverage** — what does the
caller get to *not* think about because this module exists?

A deep `chatSend` lets the caller forget about provider selection,
auth, retry, rate-limit, breaker state, and stream parsing. A shallow
`chatSend` would just call fetch and force the caller to handle all
of those.

### Seam

The location where the interface lives — the place you can alter
behaviour without editing in place. Use the word *seam*. Reject
"boundary" (overloaded with DDD bounded contexts) and "API"
(overloaded with HTTP / public-product API).

A seam is observable: you can substitute one implementation for
another across a seam without touching callers. If you can't, there's
no seam there yet.

### Adapter

A *role* — the thing that satisfies an interface. Not a Pattern™. We
say "this is the in-memory adapter for `EventStore`" not "this is the
adapter pattern." A real adapter implies the interface has been used
in **two** call-sites with **two** implementations. One adapter is
indirection; two adapters is a seam (rule below).

### Leverage / Locality

The two payoffs of a deep module:

- **Leverage** — what the caller gets to skip thinking about. Caller-
  side benefit. High leverage = small interface, big effect.
- **Locality** — what the maintainer gets to keep in one place. Owner-
  side benefit. High locality = changes to the behavior touch one
  module, not five.

A good module increases both. If you can only justify one, you don't
have a module yet — you have a function that wants a different home.

---

## Forbidden / replaced words

| Don't say | Say instead | Why |
|-----------|-------------|-----|
| boundary | seam | "Boundary" is overloaded with DDD bounded contexts |
| API | interface | "API" implies HTTP / public-product surface |
| service | module (or pick a domain verb) | "Service" is layer-thinking; we're scale-agnostic |
| util / helper / common / shared / misc | (the actual domain verb) | These are dumping grounds, not modules. Forbidden by repo-structure rule #3 |
| layer | (name the layer's concern) | "Layer" smuggles top-down design back in |
| abstraction | interface, or seam | "Abstraction" is too loose; pick the specific term |
| wrapper | adapter (if real) or delete it | Most "wrappers" are pass-throughs that fail the deletion test |
| port (without two adapters) | (don't introduce one) | One adapter is indirection; we don't ship speculative ports |
| handler / manager / processor | (the verb the thing actually does) | Nouns ending in -er are usually shallow |

---

## Three principles, used as design tests

Every architecture proposal is reviewed against these. A worker
proposing a refactor should explicitly state how each is satisfied.

### 1. Deletion test

Mentally delete the module. Walk through what happens to its callers.
**If the complexity vanishes — if the callers don't need the work the
module was doing — the module was a pass-through and shouldn't exist.**

The deletion test is the cheapest architecture review you can do. Run
it before designing the interface, not after.

Pass: deleting `chatSend` would force every caller to write provider
selection + auth + retry — real work. The module earns its keep.

Fail: deleting `formatDate` would force every caller to write
`d.toISOString().slice(0, 10)`. That's not real work. The module is a
pass-through; inline it.

### 2. The interface is the test surface

If you find yourself wanting to test "past" the interface — reach into
internals, inspect private state, mock a function the public interface
doesn't expose — **the module is the wrong shape**, not the test.

The test is reporting a design problem. Either:

- The interface is too narrow (move some private behavior into the
  public surface, then test it through the surface), or
- The module is too deep in the wrong direction (split it; test each
  piece through its own surface).

Layered tests (unit + integration of the same code path) are a sign of
the same disease. Replace them, don't stack them.

### 3. One adapter is hypothetical, two adapters is a real seam

We **refuse speculative ports**. An interface that has exactly one
implementation is not a seam — it's a thin wall around the
implementation, paid for in indirection cost.

A seam is real when at least two implementations exist (production +
in-memory test double, or local + remote, or cloud A + cloud B). If
you can't name two, don't introduce the port. Inline it; you can
extract later when the second adapter actually arrives.

---

## How to apply

When proposing a refactor or designing a new feature:

1. State the **module** in domain-verb terms.
2. List the **interface** — the *full* interface, not just signatures.
3. Run the **deletion test** out loud. If it fails, stop.
4. Identify the **seam(s)**. Are there two adapters today? If not, no
   seam; just write the implementation directly.
5. Score the **leverage** and **locality** the change buys. If neither
   improves, you're not ready.
6. Pick names that match the vocabulary above. Reject substitutes.

When reviewing a worker's output:

- Search the worker's prose for forbidden words. If found, ask the
  worker to rephrase before reading further. (Vocabulary drift is a
  load-bearing signal — when it's wrong, the design under it is
  usually wrong too.)
- Apply the deletion test to anything new the worker proposes.
- For any new "port" or "adapter," ask: which two adapters exist today?

---

## Provenance

This vocabulary is adapted from Matt Pocock's
`improve-codebase-architecture/LANGUAGE.md` (MIT). Local extensions:
the forbidden-words table is project-specific (util/helper/common are
forbidden by our `repo-structure` skill rule #3); the deletion test
integration with our `test-first` skill is local; the upstream file is
referenced read-only under `.claude/skills/_upstream/` once vendored
via Week 4 of the deep-modules adoption.
