---
name: maven-cli
description: Maven CLI invocation patterns. Use whenever running `mvn` commands in Java/Maven projects. Covers when `-am` is required, why `-o` (offline) mode hides bugs in multi-worktree setups, and how to verify compile/test cleanly without trusting stale `~/.m2` artifacts.
---

## Avoid `-o` / `--offline`

Do not pass `-o` (or `--offline`) to `mvn` by default.

**Why:** In multi-worktree or multi-branch Maven projects, `~/.m2/repository` accumulates artifacts installed by other worktrees and branches. Those cached artifacts may have been compiled against different transitive versions than the current branch's POM resolves. Running with `-o` makes Maven trust the cached install for sibling modules instead of rebuilding them from source. The result is a phantom compile error caused by local-cache mismatch — for example, a sibling module compiled against Dropwizard 3 leaking `io.dropwizard.core.ConfiguredBundle` references into a Dropwizard 2 build. The error looks like an upstream defect but the actual cause is local cache pollution from another branch.

**How to apply:** When verifying that a module compiles after a change, use `mvn -pl <module> -am compile` (or `clean install -DskipTests`) instead. The `-am` ("also-make") flag rebuilds upstream sibling modules from the current worktree's source, invalidating any stale cache entries.

If `-am` itself fails on an upstream module, fix that root cause. Do not bypass it with `-o`.

Reserve `-o` for situations where the cache is known to be in sync with HEAD (for example, immediately after a successful `mvn install` from the same branch) or where the goal is specifically to test offline behavior.

## Don't use stash-and-rerun to acquit your diff

When a build fails after a change, do not run `git stash && mvn ...` and conclude from a matching error that the diff is innocent. Both states resolve dependencies from the same `~/.m2` cache, so the comparison is not independent. A polluted cache will fail identically with or without the diff applied — and the matching error then becomes false evidence that the change is fine.

**How to apply:** Reproduce against a freshly built dependency graph. The cheapest reliable form is `mvn -pl <module> -am clean install -DskipTests`. If that succeeds, the earlier failure was local-cache pollution and the diff is fine. If it still fails, the failure is real and needs fixing in the diff.

## Prefer `-pl <module> -am` over building everything

For verification during development, scope the build to the module under change plus its upstream dependencies (`-pl <module> -am`). This is faster than a root-level build and exercises the exact compile classpath the changed module sees. Save full reactor builds for release verification or when the change spans many modules.
