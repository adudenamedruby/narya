# Guidelines on Adding Functionality to `narya`

## What should be added to `narya`

### 1. Workflows that map to CI / GitHub Actions

If the repo runs a task in CI (build, lint, test, package, verify), it’s a strong candidate to be runnable via `narya`.

> Rule: If CI runs it, `narya` should be able to run it locally with the same defaults (or explain what’s different).

Examples:

- lint suites, formatting checks
- unit/UI tests, sharding/retry wrappers
- “PR gate” sets
- validation jobs (license, config, localization checks)

### 2. High-frequency local commands

Commands that people run weekly or more should be first-class.

Examples:

- build/run/test
- clean derived data / repo artifacts
- simulator app-data reset
- lint + fix
- environment checks (doctor)

### 3. “Glue” that prevents common mistakes

If developers routinely:

- forget a required flag
- run steps in the wrong order
- produce non-reproducible results
- waste time debugging predictable environment issues

…then the `narya` should probably encode the correct path.

Examples:

- “autocorrect then re-lint”
- “run tests with correct destination/device”
- “ensure correct Xcode + runtime installed”
- “show exactly what will be deleted before cleaning”

### 4. Tasks that require repo context

If it depends on repo conventions (schemes, paths, configs), it belongs in `narya` instead of a generic script.

Examples:

- locating the right DerivedData directory for this repo
- mapping “changed files” to the right lint/test subset
- finding/printing bundle id(s) and schemes used in the repo

## What should NOT be added to `narya`

### 1. One-off personal utilities

If only one person uses it, or it’s for a niche workflow, it doesn’t belong in the default CLI.

Instead:

- document it as a snippet in CONTRIBUTING
- keep it as a script under tools/ until it proves broadly useful

### 2. Wrappers that add no value

If `narya` foo is just somecommand foo with no defaults, no validation, no repo-specific behavior, don’t add it.

> Rule: `narya` should not be a thin alias collection.

### 3. Commands that require secrets/signing by default

Don’t bake in workflows that routinely require sensitive credentials unless:

- they’re opt-in
- they handle redaction safely
- they fail clearly with next steps

(Example: release packaging/signing should be guarded and explicit.)

### 4. Interactive-only flows

`narya` should work in CI and scripts. Interactive prompts must be avoidable.

> Rule: Every command must support non-interactive mode:

- through `--yes` / `--no-input` flags if needed

- exit non-zero with actionable guidance if confirmation is required

## How to decide: top-level command vs subcommand

### Top-level commands are for “domains”

A top-level command should represent a distinct area of work with multiple related actions.

Good top-level domains:

- build, run, test
- lint, format/fix
- clean
- deps (SPM-focused)
- sim
- ci
- version
- doctor
- bootstrap

> Rule: If it’s something you’d type from memory and use often, it’s probably top-level.

### Subcommands are for specific actions within a domain

Subcommands should be verbs or targets under that domain.

Examples:

- `narya` test unit|ui|smoke
- `narya` lint [--changed|--all|--ci]
- `narya` clean deriveddata|spm|artifacts|sim
- `narya` sim list|boot|shutdown|erase
- `narya` version show|bump|set|verify

> Rule: If it shares inputs/flags/output conventions with siblings, it’s a subcommand.

### Avoid overloading verbs as top-level commands

Names like `update`, `run`, `do`, `make`, `tools` become junk drawers.

Prefer explicit domains:

- `deps update` instead of `update deps`
- `version bump` instead of `update version`

> Rule: If a name could plausibly apply to 3+ unrelated things, it’s not a good top-level command.

## Naming and ergonomics rules

### Command naming

- prefer short, standard nouns: lint, test, sim, deps, ci
- prefer verbs for subcommands: list, show, bump, verify, erase
- avoid abbreviations unless extremely common (ci, sim, spm are fine)

### Aliases

Aliases are allowed only when:

- they’re extremely common (`narya` b → `narya` build)
- they don’t introduce ambiguity
- the full command remains the “official” one in docs

### Output and behavior requirements (to keep the tool consistent)

Every new command must:

- print a concise summary
- clearly separate `narya` output from passthrough tool output
- support --verbose and --quiet (if applicable)
- support `--json` when the output is naturally structured (if applicable)

### Promotion path: from script → first-class command

A new utility should follow this lifecycle:

1. Start as a script in tools/ (or similar)
2. Get used by multiple contributors / referenced in docs or issues
3. Once it has stable semantics, wrap it as `narya` <domain> <subcommand>

If it becomes part of CI, it must be runnable via `narya ci …`

> Rule: Don’t add “brand new” workflows directly to `narya` unless they’re immediately required for CI parity.

## Design principle: `narya` is opinionated, not everything

When a tradeoff exists, `narya` should encode the repo’s preferred defaults, but allow escape hatches.

Examples:

- default to --changed locally, --all in CI
- default simulator selection, allow explicit --device
