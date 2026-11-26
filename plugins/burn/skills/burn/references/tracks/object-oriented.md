---
name: object-oriented
applies: any
shard: directory
invokes: "an object-oriented design review over {paths}"
evidence: "Each refactoring names the fact or rule it gives one home, lists the call sites that now ask that home instead of working it out themselves, and the build and tests pass unchanged after it: no test assertion edited to fit."
---

Find facts and rules that are scattered across callers, give each one a single home on the type it describes, and change the callers to ask that type. Deduplication follows from this: once a fact has one home, its copies collapse, and copies that had drifted apart turn out to be bugs.

Look for these shapes:

- **Reaching through an object to learn a fact about it.** `unit.getContext().getParent() != null` written at several call sites is a fact about `unit`. Add a method with the domain name, such as `isGrafted()`, and the accessor it implies, such as `getGraftContext()`, then replace every hand-written version.
- **Generic structures standing in for a concept.** A `Pair<Token, Token>`, a two-element array or a map from a string means something it does not say. Replace it with a named record or value type, and replace a `null` that means "none" with `Optional`.
- **Values that always travel together and must agree.** Two maps or lists passed side by side everywhere, with a consistency check repeated where they meet, belong in one type that holds both and checks the rule once, in its constructor.
- **The same query pipeline written by hand more than once.** A chain of collect, filter, unwrap and distinct over the same type is an operation on that type. Make it a method on the type, or a static method on its interface for collections of it.
- **Identical overrides in sibling subclasses.** Move the body up to the base class as the default and drop the abstract declaration.
- **Stored copies of something that can be derived.** A field or a whole subclass that exists only to carry a value computed eagerly, such as a cause, a parent or a current element, is a cache. Derive the value from its source when it is asked for, and collapse a class hierarchy whose members differ only in that stored value into one class. Holding a key and looking the object up beats holding a second reference that has to be kept in sync on enter and exit.
- **Data that knows how to present itself.** When a data type takes a color scheme, a format or an output target, split rendering into a renderer object that callers build and pass in, so the data type is plain data and each output is its own renderer.
- **Near-copies of one path.** Strict and lenient variants, or create and update variants, that repeat the same conversion belong on one shared core. Diff the copies first: where they disagree, one of them is usually a bug, and the shared version fixes it.

Follow how the codebase already models things, in its language and collection style, and leave a module written in a deliberately functional style functional.

Make one refactoring per commit, and name in the message what was added and what it replaced, in the form "Add X, replacing Y spread across Z". Commit only when the build, type check and tests pass with no test assertion changed; tests may change only where they call a moved or renamed API. When unifying near-copies fixes a difference between them, say so in the commit message and add a test for the fixed case.

A refactoring that changes a public API other code outside the repository may use, or that needs a design decision such as which of two disagreeing copies is right, is a finding with the scattered fact, its locations and the home you would give it. With nothing refactored, commit nothing.
