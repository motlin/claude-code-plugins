---
name: maven-cli
description: Maven CLI invocation patterns. Use whenever running `mvn` commands in Java/Maven projects. Covers when `-am` is required, why `-o` (offline) mode hides bugs in multi-worktree setups, and how to verify compile/test cleanly without trusting stale `~/.m2` artifacts.
---

# Maven CLI

## Avoid `-o` / `--offline`

Do not pass `-o` or `--offline` by default.

In multi-worktree or multi-branch projects, `~/.m2/repository` holds artifacts installed by other worktrees, possibly compiled against different transitive versions than this branch resolves. Offline mode makes Maven trust those cached sibling modules instead of rebuilding them, producing phantom compile errors that look like upstream defects. Example: a sibling module compiled against Dropwizard 3 leaking `io.dropwizard.core.ConfiguredBundle` references into a Dropwizard 2 build.

To verify a module compiles, use `mvn -pl <module> -am compile` (or `clean install -DskipTests`). `-am` rebuilds upstream siblings from this worktree's source. If `-am` fails on an upstream module, fix that root cause rather than falling back to `-o`.

Use `-o` only when the cache is known to match HEAD (for example, right after a successful `mvn install` from the same branch) or when testing offline behavior specifically.

## Don't use stash-and-rerun to acquit your diff

`git stash && mvn ...` failing with the same error does not prove the diff innocent. Both runs resolve from the same `~/.m2` cache, so a polluted cache fails identically either way.

Reproduce against a freshly built dependency graph instead: `mvn -pl <module> -am clean install -DskipTests`. If it succeeds, the earlier failure was cache pollution. If it still fails, the failure is real.

## Prefer `-pl <module> -am` over building everything

During development, scope builds to the changed module plus its upstream dependencies. It is faster than a root build and uses the exact classpath the module sees. Save full reactor builds for release verification or changes spanning many modules.
