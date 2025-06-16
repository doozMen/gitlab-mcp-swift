# GitLab MCP Usage Guide

## Overview

The GitLab MCP (Model Context Protocol) Server provides a structured interface to interact with GitLab through AI assistants. It wraps the `glab` CLI tool, making GitLab operations accessible through standardized tool calls.

## Getting Started

### Prerequisites
1. Install and authenticate `glab`:
   ```bash
   # Install glab (see https://gitlab.com/gitlab-org/cli)
   brew install glab  # macOS
   
   # Authenticate
   glab auth login
   ```

2. Install the MCP server:
   ```bash
   pip install -e .
   ```

## Available Tools

### Core Tools

#### `glab_examples`
Get practical examples for common GitLab operations.
- **Usage**: `glab_examples(topic="general")`
- **Topics**: `general`, `mr`, `issue`, `ci`, `repo`, `api`
- **Example**: `glab_examples(topic="mr")` - Shows merge request examples

#### `glab_help`
Get detailed help for any glab command.
- **Usage**: `glab_help(command="mr create")`
- **Example**: `glab_help(command="issue list")` - Shows how to list issues

#### `glab_raw`
Execute any glab command with full control.
- **Usage**: `glab_raw(args=["mr", "list", "--assignee=@me"])`
- **Best for**: Complex commands or when you need precise control

### Resource-Specific Tools

Each GitLab resource has its own tool following the pattern `glab_{resource}`:

#### `glab_mr` - Merge Requests
- **Common subcommands**: `list`, `create`, `view`, `approve`, `merge`, `update`
- **Example**: 
  ```python
  glab_mr(
    subcommand="list",
    args=["--assignee=@me", "--state=opened"],
    format="json"
  )
  ```

#### `glab_issue` - Issues
- **Common subcommands**: `list`, `create`, `view`, `close`, `reopen`, `update`
- **Example**:
  ```python
  glab_issue(
    subcommand="create",
    args=["--title", "Bug: Login fails", "--label", "bug"]
  )
  ```

#### `glab_ci` - CI/CD Pipelines
- **Common subcommands**: `view`, `list`, `retry`, `cancel`
- **Example**:
  ```python
  glab_ci(subcommand="view")
  ```

#### `glab_repo` - Repositories
- **Common subcommands**: `clone`, `fork`, `view`, `list`, `archive`
- **Example**:
  ```python
  glab_repo(
    subcommand="clone",
    args=["group/project"]
  )
  ```

## Common Usage Patterns

### 1. List Your Open Merge Requests
```python
glab_mr(
  subcommand="list",
  args=["--assignee=@me", "--state=opened"],
  format="json"
)
```

### 2. Create a New Issue
```python
glab_issue(
  subcommand="create",
  args=["--title", "Feature: Dark mode", "--description", "Add dark mode support"]
)
```

### 3. View CI Pipeline Status
```python
glab_ci(subcommand="view")
```

### 4. Update MR Description
```python
glab_mr(
  subcommand="update",
  args=["123", "--description", "Updated description with more details"]
)
```

### 5. Use GitLab API Directly
```python
glab_api(
  args=["GET", "/user"]
)
```

## Tips and Best Practices

1. **Use `format="json"`** when you need structured data for further processing
2. **Start with `glab_examples`** to see practical examples for your use case
3. **Use `glab_help`** to understand available options for any command
4. **Error messages include helpful tips** - read them for troubleshooting guidance
5. **Repository context**: Either run from within a Git repository or use the `-R` flag

## Troubleshooting

### Authentication Issues
If you see authentication errors:
```bash
glab auth login
```

### Repository Not Found
Make sure you're either:
- In a Git repository directory, or
- Specifying the repository with `-R owner/repo` in args

### Permission Denied
Check your access rights to the repository or resource.

### Getting More Help
1. Use `glab_help(command="command_name")` for command-specific help
2. Use `glab_examples(topic="topic_name")` for practical examples
3. Check the error messages - they include context-specific tips

## Advanced Usage

### Working with Different Repositories
```python
glab_mr(
  subcommand="list",
  args=["-R", "gitlab-org/gitlab", "--state=merged"]
)
```

### Pagination and Filtering
```python
glab_api(
  args=["GET", "/projects/:id/merge_requests", "--paginate", "--per-page=100"]
)
```

### Custom Output Processing
```python
# Get JSON output for processing
result = glab_issue(
  subcommand="list",
  format="json"
)
# The result will contain structured data you can parse
```