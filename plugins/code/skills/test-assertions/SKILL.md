---
name: test-assertions
description: Write test assertions as complete, strict deep-equality checks, and hold existing tests to the same standard. Use when writing new tests, adding assertions, reviewing test quality, strengthening weak tests, or replacing fragmented assertions in a file, directory, diff, or repository.
---

# Strict Test Assertions

Write each assertion to capture a value's complete structure in one strict deep-equality check. Reach for one full-value assertion first rather than a cluster of narrow checks you consolidate later. Hold existing tests to the same standard when reviewing or strengthening them.

## Select the scope

- Use the file or directory named by the user when provided.
- Otherwise, use test files in staged and unstaged changes when the working tree contains changes.
- Otherwise, use all test files in the repository.

Do not change snapshots unless the user explicitly includes them.

## Prefer the strongest assertion

Use the strictest deep-equality matcher the framework offers for objects, arrays, sets, maps, class instances, and other structured values (in Jest, `toStrictEqual`). Replace looser equality, partial matchers, property checks, containment checks, length checks, and existence guards when one complete assertion can express the expected value.

Use exact-equality for primitives (in Jest, `toBe`). Tighten calls and exceptions to their exact observable contract: the exact arguments, error type, and message.

Assert native collection types directly rather than converting them to arrays.

## Discover expected values from the test

Do not infer an expected value from implementation code. When writing a new assertion or replacing a weak one, start with a deliberately incomplete strict assertion, run the narrowest relevant test, and use the failure output to capture the actual value. Then review that value as the intended contract and rerun the test.

```ts
expect(result).toStrictEqual({});
```

If the observed value reveals a bug or an unclear contract, stop and ask the user instead of blessing it as expected behavior.

## Assert the whole value at once

Write one structural assertion instead of several narrow ones; collapse fragmented assertions in existing tests the same way:

```ts
expect(result).toStrictEqual({
	id: 'order-100',
	status: 'confirmed',
	items: [
		{sku: 'A-100', quantity: 2},
		{sku: 'B-100', quantity: 1},
	],
	shipping: {method: 'express', estimatedDays: 3},
});
```

Do not retain redundant length, existence, or property assertions before a complete value assertion.

## Control dynamic properties

Prefer deterministic test data: freeze time, inject identifiers, and use fixed test paths. When a value genuinely comes from outside the test's control, assert that property separately, remove it from the value, and strictly assert everything remaining.

Do not turn type checks into booleans inside assertion objects; that hides the actual value in failures. For deterministic dates, assert the exact value, such as `new Date("2000-01-01T00:00:00.000Z")`.

Extract expected values longer than about 50 lines into a clearly named constant or fixture.

## Verify

Run the narrowest affected tests while discovering values, then run the repository's applicable test and precommit checks. Leave no placeholder assertions behind.
