---
name: diataxis
applies: has-docs
shard: directory
invokes: "Diátaxis (https://diataxis.fr/) over the docs in {paths}"
evidence: "Each change names the doc, the Diátaxis type it serves (tutorial, how-to guide, reference or explanation) and the mixing or gap it fixes, and every fact the changed docs state is still traceable to the original text or the code."
---

Restructure the docs in the shard along Diátaxis, which sorts documentation into four types by what the reader needs: tutorials teach a beginner by doing, how-to guides walk a competent user through one task, reference describes the machinery accurately and completely, and explanation gives background and reasons. Read <https://diataxis.fr/> first when you do not already know its rules for each type.

Look for docs that mix types, such as a reference page that wanders into tutorial steps or a how-to guide stuffed with background, and split or move the parts so each doc serves one type. Fix titles and openings that do not say which need a doc meets, and link related docs of different types to each other.

Never invent content. Move, split, retitle and trim what exists, and check every moved fact against the code; one that is wrong goes in a finding, not into the new structure. Leave docs that are generated, vendored, or skill and agent instructions, since those are prompts, not documentation for readers.

A missing type, such as a project with reference docs but no how-to guide for its main task, is a finding with the doc it would go beside and an outline, not a page you write. With nothing to restructure, commit nothing.
