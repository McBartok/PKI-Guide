---
title: Navigation and sidebar ordering
parent: Reference
nav_order: 3
---

# Navigation and sidebar ordering

Use `nav_order` front matter on every page you want in a deterministic sequence.

## Recommended module ordering (01-07)

If you want strict chronological order in the sidebar:

```yaml
---
title: 1. Cryptography foundations
parent: Learn path
nav_order: 1
---
```

Apply that pattern consistently for all Learn modules:
- Module 01 → `nav_order: 1`
- Module 02 → `nav_order: 2`
- ...
- Module 07 → `nav_order: 7`

For supporting pages:
- Debugging cheat sheet → Reference `nav_order: 1`
- Trust failures/case studies → Reference `nav_order: 2`
- Glossary → Reference `nav_order: 4`

## Recommended `_config.yml` baseline

```yaml
title: PKI & Certificate Flow
remote_theme: just-the-docs/just-the-docs
search_enabled: true
heading_anchors: true
back_to_top: true
back_to_top_text: Back to top
```

Notes:
- `nav_order` in page front matter is the primary mechanism for chronological sidebar sorting.
- Keep the section index pages (`learn/index.md`, `reference/index.md`) as `has_children: true`.
- Use stable titles and file names to avoid accidental reorderings during edits.
