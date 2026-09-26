---
name: test-assertions
description: Write test assertions as complete, strict deep-equality checks, and rewrite existing tests to the same standard. Use when writing new tests, adding assertions, reviewing test quality, strengthening weak tests, or replacing fragmented assertions in a file, directory, diff, or repository.
---

# Strict Test Assertions

Capture a value's complete structure in one strict deep-equality check instead of a cluster of narrow checks. When rewriting existing tests, rethink each test as a whole rather than tweaking individual lines, and collapse weak assertions about the same value into one strict check against the complete expected value.

## Select the scope

- Use the file or directory named by the user when provided.
- Otherwise, use test files in staged and unstaged changes when the working tree contains changes.
- Otherwise, use all test files in the repository.

Do not change snapshot assertions (`toMatchSnapshot`) unless the user explicitly includes them.

## Prefer the strongest assertion

Use the strictest deep-equality matcher the framework offers for structured values (in Jest, `toStrictEqual`). Ranked from worst to best, in Jest and Chai terms; only the last is good enough:

- `toBeTruthy`, `toBeDefined`, `not.toBeNull`: barely checks anything
- `toHaveProperty('key')`: only checks existence, not value
- `toContain`, `toMatch`: substring/regex match hides the full value
- `toHaveLength(n)`: only checks count, not contents
- `toMatchObject`, `objectContaining`, `arrayContaining`: allows extra properties to sneak in
- `toEqual`, `to.deep.equal`: close, but ignores class mismatches and undefined vs missing
- **`toStrictEqual`**: the only acceptable assertion for objects and arrays

Migrate existing `toEqual` and `to.deep.equal` assertions to `toStrictEqual` too. Use exact equality for primitives (in Jest, `toBe` is fine for strings, numbers, booleans, null). Tighten calls and exceptions to their exact observable contract: the exact arguments, error type, and message.

- `toThrow()` or `toThrow(/partial/)` → `toThrow(new SpecificError("exact message"))`
- `toHaveBeenCalled()` → `toHaveBeenCalledWith("exact", "args")`

## Discover expected values from the test

Do not infer an expected value from implementation code. When writing a new assertion or replacing a weak one, start with a deliberately incomplete strict assertion, run the narrowest relevant test, and use the failure output to capture the actual value. Then review that value as the intended contract and rerun the test to confirm it passes.

```ts
// Before: three assertions that barely check anything
const result = await Children.run(['--json', '--projects-dir', '/tmp/fake-projects']);
expect(result).toHaveProperty('projects');
expect(result).toHaveProperty('summary');
expect(result.summary.total).toBe(2);

// First: replace with a placeholder; do NOT guess the expected value
expect(result).toStrictEqual({});

// Then: run the test, read the actual value from the error output, paste it in
expect(result).toStrictEqual({
	projects: [
		{name: 'project-a', path: '/tmp/fake-projects/project-a'},
		{name: 'project-b', path: '/tmp/fake-projects/project-b'},
	],
	summary: {total: 2, active: 2},
});
```

If the observed value reveals a bug or an unclear contract, stop and ask the user instead of blessing it as expected behavior.

## Assert the whole value at once

Even when each assertion is already strict, splitting them across properties loses the structural picture and makes failures harder to diagnose:

```ts
// Before: correct but fragmented; each line is fine on its own
const result = processOrder(input);
expect(result.id).toBe('order-42');
expect(result.status).toBe('confirmed');
expect(result.total).toBe(119.99);
expect(result.currency).toBe('USD');
expect(result.items).toStrictEqual([
	{sku: 'A1', qty: 2},
	{sku: 'B3', qty: 1},
]);
expect(result.shipping.method).toBe('express');
expect(result.shipping.estimatedDays).toBe(3);
expect(result.tags).toStrictEqual([]);

// After: one assertion captures the complete value
expect(result).toStrictEqual({
	id: 'order-42',
	status: 'confirmed',
	total: 119.99,
	currency: 'USD',
	items: [
		{sku: 'A1', qty: 2},
		{sku: 'B3', qty: 1},
	],
	shipping: {method: 'express', estimatedDays: 3},
	tags: [],
});
```

### Redundant guards

Don't assert length, size, or existence right before asserting the full value; the content assertion already implies it:

```ts
// BAD: toHaveLength is redundant
expect(result).toHaveLength(2);
expect(result[0].name).toBe('a');
expect(result[1].name).toBe('b');

// GOOD: one assertion covers length AND contents
expect(result.map((r) => r.name)).toStrictEqual(['a', 'b']);
```

Same for `toBeDefined()` / `not.toBeNull()` before property access: if the value were nullish, the next line would throw anyway.

### Native collection types

Assert Sets and Maps directly rather than converting them to arrays:

```ts
// BAD: pointless conversion
expect([...result]).toStrictEqual(['a', 'b']);

// GOOD: assert the actual type
expect(result).toStrictEqual(new Set(['a', 'b']));
```

## Control dynamic properties

Prefer deterministic test data for timestamps, temp paths, and UUIDs: freeze time, inject identifiers, use fixed test paths. When a value comes from outside the test's control, don't fall back to weak assertions. Assert the dynamic properties individually, strip them, and assert strict equality on the rest:

```ts
const result = await createReport();

// Assert dynamic properties individually
expect(result.createdAt).toBeInstanceOf(Date);
expect(result.tempDir).toMatch(/^\/tmp\//);

// Strip them, then assert everything else strictly
const {createdAt, tempDir, ...rest} = result;
expect(rest).toStrictEqual({
	title: 'Q1 Report',
	status: 'complete',
	items: [{id: 1, name: 'revenue'}],
});
```

Never put `instanceof` or type checks inside assertion objects. A failure then shows `false !== true` instead of the actual value.

```ts
// BAD: hides the actual value
expect({createdAt: result.createdAt instanceof Date}).toStrictEqual({
	createdAt: true,
});

// GOOD: shows the actual value on failure
expect(result.createdAt).toStrictEqual(new Date(1_704_067_200 * 1000));
```

When the full expected value would be enormous (more than about 50 lines), extract it into a clearly named `const` at the top of the test or a fixture file.

## Verify

Run the narrowest affected tests while discovering values, then run the repository's applicable test and precommit checks. Leave no placeholder assertions behind.
