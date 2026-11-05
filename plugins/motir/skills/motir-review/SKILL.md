---
name: motir-review
description: Review a Motir card's pull requests against the card and every card under it, then hand Motir ONE verdict — `motir review <KEY>` or `motir review <PR URL>`. Use when the user asks to review a card, review this PR, review a story before it merges, or says a review is waiting for their own review agent. This is the INTERACTIVE review a person runs from their own coding agent with their own Motir sign-in, not Motir's hosted review container. It builds one checklist row per acceptance criterion across the card tree, runs a correctness pass over the code, and submits one verdict per run target through `submit_review_verdict`. It never approves, merges, pushes, claims, changes a status, edits a card or posts to the pull request; the verdict call is its only write, and a person still approves the merge.
motir-public-only: true
---

# `motir review <KEY | PR URL>` — review a card and hand Motir the verdict

A card in **In review** waits for two things: an agent review of what its pull requests did, and a
person who approves the merge. This skill is the first of those, run by **you** with your own coding
agent. It checks every acceptance criterion of the card and of every card under it against the code,
looks for defects the criteria do not mention, and submits ONE verdict for each card that is reviewed
on its own. Motir records it against the card, its bot posts it on the pull requests, and the person
still decides the merge.

Talk to Motir only through its MCP tools, named exactly as the server names them (your client may
prefix them, e.g. `mcp__motir__get_work_item`), plus `git` and `gh` for reading pull requests. If the
Motir tools are not there, stop and say how to connect them: in Claude Code with the `motir` plugin,
run `/mcp` and authenticate `motir`; otherwise follow <https://motir.co/docs/mcp>. If a call fails with
a connection error or a 401, stop and report what you were about to do.

**Do not ask the person to choose how to review.** A detail this procedure leaves open is decided by
the repository's own conventions (its `CLAUDE.md` / `AGENTS.md`, its coding convention) and, where they
are silent, the established practice for the stack.

## 1. Resolve the target

- **A key** (`ACME-12`) names the card: `get_work_item { key }`.
- **A GitHub pull request URL** is resolved with `find_work_items_for_pull_request { url }`.
  - `linked` — review the cards it answers (step 5 says how many verdicts that is).
  - `not_linked` — say so in plain words, with its reason, and **stop: review nothing and submit
    nothing**. `no_deliveries`: the pull request delivers no Motir card. `pull_request_unknown`: Motir
    has not seen that pull request. `repository_not_connected`: the repository is not connected to
    this Motir workspace.
- **A URL that is not GitHub** (GitLab, Bitbucket, anything else) is refused the same way: say Motir's
  review reads GitHub pull requests only, and stop.

## 2. Read the card tree and check out the code

- Read the target and **every descendant** (`get_work_item` on each child, down to the leaves): its
  body, its acceptance criteria, and its How to test where it has one.
- Collect every pull request the cards deliver. Check each one out **read-only** at its head:
  `gh pr checkout <n> --detach` into a clean worktree, or `git fetch origin pull/<n>/head` and
  `git worktree add --detach <dir> FETCH_HEAD`. Never switch branches in a dirty tree and never push.
  Without a checkout, read the change with `list_changed_files` and `read_file`.
- Note each pull request's head commit (`gh pr view <n> --json headRefOid`). The **delivery-set
  version** you review is every pull request of a run target as `owner/name#number@headSha`, sorted,
  comma-joined — the verdict names it.

## 3. Build the criteria checklist

One row per acceptance criterion, across the target and every descendant, each with the card's key:

| status | when |
|---|---|
| `met` | the code does it, and you can **show** it: a file and line, a test that asserts it, a command's output. |
| `not_met` | the code does not do it, or does something else. |
| `cannot_tell` | you could not settle it — say what would (a manual click-path, a secret you lack). Never guess. |

- **No row is `met` without evidence.** A row you cannot evidence is `cannot_tell`.
- A card that states **no acceptance criteria** is a row of its own, and a finding — never a pass.
- A **cancelled or archived** descendant is listed as skipped and not reviewed.
- A child whose own delivery **already merged** is checked against the default branch and marked merged.

## 4. The correctness pass

Over the code in the pull requests, ask: does it do what the cards say, and is anything wrong that the
criteria do not mention — a wrong branch, a missing state, an unhandled error, a tenant or permission
hole, a test that cannot fail?

- Use your own code-review skill if you have one, **without posting anything**; otherwise read the diff
  file by file with those questions.
- **Verify every finding before you report it**: read the code it names, or run only the one test file
  it touches — never the full suite. Drop anything you cannot verify.
- Rank each finding **blocker**, **major**, **minor** or **nit**, and write it with the file and line,
  what is wrong and what to change.

## 5. Submit ONE verdict per run target

**The verdict rule:** `approved` only when **no checklist row is `not_met`** and the correctness pass
found **no blocker or major** finding. Otherwise `changes_requested`. `cannot_tell` rows alone never
send a card back, and minor findings and nits never do; they are listed for the person.

- Submit with `submit_review_verdict { key, verdict, subjectVersion, summaryMd, findingsMd, checklist,
  harness, model }`:
  - `findingsMd` — required and non-empty on `changes_requested`; every finding, ranked, with the
    checklist table at its top.
  - `checklist` — the rows of step 3, each `{ key, criterion, status, evidence }`; `evidence` is required
    on a `met` row.
  - `subjectVersion` — the delivery-set version you reviewed (step 2).
  - `harness` — your own name as your makers write it (`Claude Code`, `Codex`, …); `model` — the model id
    you run as. Do not guess a model id you do not know; say so to the person instead.
- **One verdict per run target, never one for a tree.** A run target is a card whose own pull requests
  its tests run on. A leaf with its own pull request is one. A story whose children ride its one branch
  is one. When the target is a container whose children deliver their own pull requests, each such
  child is a run target: submit one verdict for each, never a single verdict for the container.
- **A story's own criteria count against every pull request in its tree.** A story criterion that is
  `not_met` goes into the verdict of every run target it depends on — or of all of them when it cannot
  be attributed to one — so a story never passes piecemeal.

## 6. Refusals — by name

| refusal | what to do |
|---|---|
| `REVIEW_VERDICT_LATE` | A push moved the head while you reviewed; the verdict was stored as late and decided nothing. Re-read the new head and review again **once**. If it moves again, report and stop. |
| `REVIEW_VERDICT_SECOND` | That version already has a verdict. Report it and stop for that card. |
| `REVIEW_TARGET_NOT_RUN_TARGET` | The card is reviewed as part of the run target the refusal names. Review that card instead. |
| `REVIEW_NOTHING_TO_REVIEW` | The card delivers no pull request. Say so; nothing is owed. |
| `INVALID_REVIEW_VERDICT` | The field it names is wrong (empty findings, a `met` row without evidence). Fix that field and submit again. |
| a permission refusal | Your token lacks `work_item:edit` on the project. Say so and stop. |

## 7. Report to the person

The checklist (every row, with its evidence or what would settle it), the findings by rank, and each
verdict you submitted with its outcome: `decided` (an awaiting review was decided), `recorded` (no
review gate was waiting; it is on the card's record), or the refusal.

## What this skill never does

It never approves or merges, pushes, claims a card or a run, changes a status, edits a card, or
comments on or posts to a pull request — from your account or anyone's. Motir's own bot posts the
verdict on the pull requests. **The one write this skill makes is the verdict call**, and a person
still approves the merge.
