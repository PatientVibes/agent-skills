# graphify

Any input → navigable knowledge graph. Plugin in the `patientvibes-skills` marketplace.

## Status: v1

The companion CLI is `graphify`. Skill assumes the binary is installed and on `PATH`.

## Skills

### `graphify`

Triggered by `/graphify` or when the user asks any question about a codebase or document set (especially if `graphify-out/` already exists in the current directory). Turns any folder of files — code, docs, papers, images, videos — into a navigable knowledge graph with community detection and an honest audit trail.

Three outputs:
- Interactive HTML
- GraphRAG-ready JSON
- Plain-language `GRAPH_REPORT.md`

## Install

```
/plugin marketplace add D:/agent-skills
/plugin install graphify@patientvibes-skills
```
