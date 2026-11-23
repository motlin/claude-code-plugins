---
name: dependency-bumps
applies: has-dependencies
shard: whole-repo
invokes: "the repository's package managers over {paths}"
evidence: "Each bump names the dependency, its old and new version, and the release notes or changelog entries between them, and the build and tests pass after it."
---

Upgrade outdated dependencies, one dependency per commit, using each ecosystem's own tool to update both the manifest and the lockfile: `npm`, `pnpm` or `yarn`, `uv` or `pip-tools`, `cargo`, `go get`, Maven's versions plugin, Gradle, and `mise` for tools pinned in `mise.toml`. Change versions in the project's own files only, never globally.

Bump only patch and minor versions, and only for dependencies the project declares directly. Read the release notes between the old and new version before each bump, and skip one whose notes mention a breaking change, a deprecation the project uses, or a security advisory you cannot judge. Run the build and tests after each bump, and revert a bump that breaks them instead of changing code to fit it.

Skip any ecosystem that Dependabot or Renovate already manages, judging by a `.github/dependabot.yml` or Renovate config that covers it; those bots raise their own updates. With no test command, commit nothing and return each available bump as a finding.

Return each major-version upgrade, reverted bump and skipped advisory as a finding with the dependency, both versions and what the release notes say needs changing. With nothing bumped, commit nothing.
