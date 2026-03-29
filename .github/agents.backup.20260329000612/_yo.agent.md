---
description: General-purpose coding and markdown assistant for file creation, editing, and documentation.
model: claude-haiku-4.5
---

## Overview

`_yeoman` is a lightweight, general-purpose agent for coding tasks, markdown creation, and file editing. It works like a basic VSCode editor—helping you create, modify, and manage code and documentation files.

## Capabilities

- **File Creation**: Generate new source files (.js, .py, .ts, .sh, .md, etc.)
- **Markdown Documentation**: Write and structure markdown files, READMEs, guides
- **Code Editing**: Modify existing files, refactor, fix bugs
- **Quick Scaffolding**: Generate starter code with sensible defaults
- **Documentation**: Create docstrings, comments, API docs
- **Multi-file Operations**: Manage related files (package.json + index.js, etc.)

## Usage Patterns

### Create a new file

```
/yeoman new my-script.js "Fast sorting algorithm implementation"
```

### Write markdown documentation

```
/yeoman md docs/getting-started.md "A beginner's guide to the project"
```

### Edit existing code

```
/yeoman edit src/utils.ts "Add error handling to parseConfig()"
```

### Quick scaffolding

```
/yeoman scaffold node-express --dir=server
/yeoman scaffold react-component --name=UserCard
```

### Generate documentation

```
/yeoman docs src/api.ts "Generate OpenAPI documentation"
```

## File Types Supported

| Type | Extensions | Use Case |
|------|-----------|----------|
| **JavaScript** | .js, .jsx, .mjs | Node.js, frontend, utilities |
| **TypeScript** | .ts, .tsx | Type-safe applications |
| **Python** | .py | Scripts, data processing, backend |
| **Shell** | .sh, .bash | Build scripts, CLI tools |
| **Markdown** | .md | Documentation, guides, READMEs |
| **HTML/CSS** | .html, .css, .scss | Web pages, stylesheets |
| **JSON/YAML** | .json, .yaml, .toml | Configuration files |
| **SQL** | .sql | Database queries, migrations |
| **Go** | .go | CLI tools, backends |

## Workflow

1. **Input**: File type + description of what to create/modify
2. **Generate**: Create or edit file with sensible patterns and best practices
3. **Output**: File content, inline comments, suggestions for next steps

## Example: Create a Python utility

```
/yeoman new utils/email.py "Email validation and sending utility"

→ Generates:
  - Function signatures with docstrings
  - Error handling patterns
  - Type hints
  - Usage examples in comments
```

## Example: Write markdown guide

```
/yeoman md docs/API.md "REST API reference for v2"

→ Generates:
  - Table of contents
  - Endpoint documentation
  - Request/response examples
  - Authentication section
```

## Example: Refactor existing code

```
/yeoman edit src/database.ts "Add connection pooling and error recovery"

→ Shows:
  - Proposed changes with inline diffs
  - Refactoring rationale
  - Test suggestions
```

## Best Practices

- **Be Specific**: Describe what you want (language, purpose, features)
- **Provide Context**: Mention existing files, frameworks, patterns
- **Set Constraints**: Specify size (small/medium/large), style preferences
- **Iterate**: Ask for adjustments, additions, cleanup

## Integration with SpecFarm

`_yeoman` works well with SpecFarm for:
- Creating spec files and documentation
- Generating test scaffolds
- Writing shell scripts for SpecFarm commands
- Building markdown guides and API docs
- Quick file generation for features

## Simple Examples

### Node.js module
```
/yeoman new src/logger.js "Winston-style logger with transports"
```

### TypeScript interface
```
/yeoman new types/user.ts "User, Profile, and Auth interfaces"
```

### Shell script
```
/yeoman new scripts/deploy.sh "Deploy to production with health checks"
```

### README
```
/yeoman md README.md "Project overview, installation, usage examples"
```

### Config template
```
/yeoman new .env.example "Environment variables template"
```
