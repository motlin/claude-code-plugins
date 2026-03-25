---
description: Rewrite tests to use strict deep equality assertions
arguments:
  - name: target
    description: File or directory containing tests to rewrite (optional)
    required: false
---

Rewrite tests to use strict deep equality assertions everywhere.

This is a full rewrite, not incremental tweaking. Rethink each test holistically. Collapse multiple weak assertions about the same value into a single strict equality check against the complete expected value.

## Assertion ranking (worst to best)

Only `toStrictEqual` is good enough. Everything else is too weak:

1. `toBeTruthy`, `toBeDefined`, `not.toBeNull` — barely checks anything
2. `toHaveProperty('key')` — only checks existence, not value
3. `toContain`, `toMatch` — substring/regex match hides the full value
4. `toHaveLength(n)` — only checks count, not contents
5. `toMatchObject`, `objectContaining`, `arrayContaining` — allows extra properties to sneak in
6. `toEqual`, `to.deep.equal` — close, but ignores class mismatches and undefined vs missing
7. **`toStrictEqual`** — the only acceptable assertion for objects and arrays

## Scope

Determine which test files to rewrite:

- If `$ARGUMENTS` is provided, use that file or directory
- If `$ARGUMENTS` is empty and there are uncommitted changes, find test files among the unstaged/staged changes
- If `$ARGUMENTS` is empty and there are no uncommitted changes, find all test files in the project

## Process

1. Identify the target test file(s) using the scope rules above
2. For each test, identify every assertion
3. Replace weak assertions with a placeholder like `expect(result).toStrictEqual({})` — do NOT guess the expected value from reading the implementation
4. Run the test and let the error message reveal the actual value
5. Copy the actual value from the error output into the assertion
6. Run the test again to confirm it passes

## What to rewrite

### Multiple weak assertions on the same value become one strict assertion

```ts
// Before: three assertions that barely check anything
const result = await Children.run([
  "--json",
  "--projects-dir",
  "/tmp/fake-projects",
]);
expect(result).toHaveProperty("projects");
expect(result).toHaveProperty("summary");
expect(result.summary.total).toBe(2);

// Step 1: replace with placeholder — do NOT guess the expected value
expect(result).toStrictEqual({});

// Step 2: run the test, read the actual value from the error output, paste it in
expect(result).toStrictEqual({
  projects: [
    { name: "project-a", path: "/tmp/fake-projects/project-a" },
    { name: "project-b", path: "/tmp/fake-projects/project-b" },
  ],
  summary: { total: 2, active: 2 },
});
```

Apply the same pattern for every assertion type in the ranking. Also tighten these:

- `toThrow()` or `toThrow(/partial/)` → `toThrow(new SpecificError("exact message"))`
- `toHaveBeenCalled()` → `toHaveBeenCalledWith("exact", "args")`
- `toBe` is fine for primitives (strings, numbers, booleans, null)

## Why toStrictEqual over toEqual

`toEqual` and `to.deep.equal` are not strict enough — a class instance passes as equal to a plain object with the same shape, and missing properties pass as equal to `undefined` properties. Always use `toStrictEqual` instead, including when migrating existing `toEqual` or `to.deep.equal` assertions.

## Handling dynamic properties

Some properties are non-deterministic (timestamps, temp paths, UUIDs). Never fall back to weak assertions. Instead, strip the dynamic properties and assert strict equality on the rest:

```ts
const result = await createReport();

// Assert dynamic properties individually
expect(result.createdAt).toBeInstanceOf(Date);
expect(result.tempDir).toMatch(/^\/tmp\//);

// Strip them, then assert everything else strictly
const { createdAt, tempDir, ...rest } = result;
expect(rest).toStrictEqual({
  title: "Q1 Report",
  status: "complete",
  items: [{ id: 1, name: "revenue" }],
});
```

Prefer fixing the test data to be deterministic (freeze time, use fixed paths) over stripping. Only strip when the dynamic value comes from outside the test's control.

## Rules

- When the full expected value would be enormous (>50 lines), extract it into a `const` at the top of the test or a fixture file
- Snapshot assertions (`toMatchSnapshot`) are out of scope for this command
