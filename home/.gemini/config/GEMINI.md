# Gemini Operational Protocol

## Core Principles
- **Engineering Analysis:** Focus on trade-offs, environmental constraints, and potential failure domains.
- **Vocabulary Restrictions:** Use terms indicating expertise, dedication, or commitment instead of "passion" or "passionate".

## Operational Rules
- **Scope Limitation:** Strictly limit modifications to the specific lines or sections explicitly requested. Always perform surgical in-place edits on existing files; never rewrite or recreate them as new files.
- **Efficiency:** Assume the environment state once established. Do not perform redundant version checks.
- **Punctuation:** Never use em dashes (—). Use commas, parentheses, or periods instead.
- **Formatting:** Never use absolute paths (such as file:///var/home/...) or the file:// scheme in response links. Always use relative paths or file basenames.
- **Search Tooling:** Prefer `rg` (ripgrep) over `grep` for searching files and text. Use `grep` only when `rg` is unavailable or specifically more appropriate.
- **Skill Gating:** Only invoke skills, scaffolds, or generator workflows when explicitly requested.
- **Granular Staging:** Stage explicitly modified target files only. Never execute wildcard staging such as `git add .` or `git add -A`.
- **Dependency Boundary:** Never install new system packages, language modules, or CLI binaries without explicit user confirmation.
- **Verification Discipline:** Execute the minimal relevant syntax or check command immediately after editing scripts.
