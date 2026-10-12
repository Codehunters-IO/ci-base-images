# Rulesets

These files are definitions, not state: editing one changes nothing until it is sent to the API.
All four are repository-level rulesets, the only kind the organisation's plan allows; the
org-level definitions in `Codehunters-IO/ci-templates/.github/ruleset/` cannot be applied yet.

| File | Applies to | In force |
|------|-----------|----------|
| `ruleset-ci-base-images-develop.json` | `develop` | ruleset `24900497` |
| `ruleset-ci-base-images-main.json` | `main` | ruleset `24900501` |
| `ruleset-ci-base-images-hardening.json` | `develop` + `main` | ruleset `24900499` |
| `ruleset-ci-base-images-tags.json` | release tags `vX.Y.Z` | ruleset `24900502` |

Both branches take changes only through a pull request and cannot be deleted or force-pushed.
**`develop` squashes; `main` takes a merge commit**, as in `ci-templates`: the release pull
request is `develop` → `main`. The hardening ruleset requires signed commits on both. Repository
admins may merge a pull request past the rules (`bypass_mode: pull_request`), never push
directly.

**No status check is required.** `pr-validation.yml` runs only when `images/`, `scripts/` or
the workflows change, so a documentation-only pull request reports no check at all. Requiring
one would leave such a pull request unmergeable. Make the validation always report (for
example, a job without the `paths` filter that passes when nothing relevant changed) before
adding `required_status_checks` to the hardening ruleset.

**Release tags** cannot be moved or deleted once created. Creating them stays open.

Apply or update:

```bash
gh api -X POST repos/Codehunters-IO/ci-base-images/rulesets --input .github/ruleset/<file>.json
gh api -X PUT  repos/Codehunters-IO/ci-base-images/rulesets/<id> --input .github/ruleset/<file>.json
```

Check what is in force rather than trusting this table:

```bash
gh api repos/Codehunters-IO/ci-base-images/rules/branches/develop --jq '[.[].type]|unique'
```
