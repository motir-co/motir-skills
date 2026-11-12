# Motir

Skills that let your coding agent work a [Motir](https://motir.co) project: take the next card from
To Do to a linked pull request, repair a card's red pull requests, carry on a card whose run died, log a verified bug where it belongs,
clear the `Bugs` folder one pull request per bug, be walked through a human card one checked step at a
time, close a manual card with a record of who confirmed it, and review a card's pull requests against
every acceptance criterion in its tree.

Installing the plugin brings two things:

- **Eight skills**: `motir-run`, `motir-fix`, `motir-continue`, `motir-log-bug`, `motir-fix-bugs`,
  `motir-guide`, `motir-mark` and `motir-review`. Each one says, in its `SKILL.md`, what to type to use it.
- **The `motir` MCP server** at `https://app.motir.co/api/mcp`. Claude Code signs into it in the
  browser the first time it is used — run `/mcp`, pick `motir`, choose **Authenticate** — and on
  Motir's consent screen you pick the workspace and approve. There is no token to create or paste.

The skills that start a run use the `motir` CLI. The plugin ships no script, so run the version these
skills are written for with `npx @motir/cli@0.8.0 <command>` (or install it once with
`npm install -g @motir/cli@0.8.0`). It needs **Node.js 22 or newer** and signs in on its own
(`motir login`).

You need a Motir account and a project, `git`, and the GitHub CLI (`gh`) where a skill reads pull
requests. Setup for other agents: <https://motir.co/docs/mcp>. Source, documentation and issues:
<https://github.com/moooon-B-V/motir-skills>.

## Licence

[MIT](LICENSE) — © moooon B.V.
