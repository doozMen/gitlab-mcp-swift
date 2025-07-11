# GitLab MCP Server Instructions for AI Assistants

## Authentication Status
- **Important**: User must be authenticated with `glab auth login`
- **Check Status**: Run `glab auth status` to verify authentication
- **Multiple Instances**: GitLab supports multiple instances (gitlab.com, self-hosted, etc.)

## Important Context
1. **Always specify repository**: For users with many repositories, always use the `repo` parameter or ensure you're in the correct directory
2. **Authentication required**: Ensure user has authenticated with the appropriate GitLab instance
3. **Use @me for user's items**: When filtering by assignee, use `@me` to get the authenticated user's items

## Tool Usage Best Practices

### 1. Start with Version Check
Always begin by using `glab_version` to:
- Verify the MCP server is running correctly
- Confirm authentication status
- Check both MCP and glab CLI versions

### 2. Merge Request Operations
For work tracking:
```json
// List user's MRs
{
  "tool": "glab_mr",
  "arguments": {
    "subcommand": "list",
    "args": ["--assignee=@me", "--state=opened"],
    "repo": "team/project"  // Always specify for specific repos
  }
}

// Check MRs across all accessible repos
{
  "tool": "glab_mr", 
  "arguments": {
    "subcommand": "list",
    "args": ["--assignee=@me", "--all-projects"]
  }
}
```

### 3. Daily Workflow Commands

#### Morning Planning
1. Check opened MRs assigned to user
2. Review MRs awaiting review
3. Check pipeline status for active branches

#### Time Tracking Integration
When integrating with time tracking systems:
- Use MR titles and descriptions for task context
- Track time against MR numbers
- Link commits to specific MRs for accurate tracking

### 4. Common Patterns

#### Get all user's active work
```json
{
  "tool": "glab_mr",
  "arguments": {
    "subcommand": "list",
    "args": ["--assignee=@me", "--state=opened", "--format=json"]
  }
}
```

#### Check specific project MRs
```json
{
  "tool": "glab_mr",
  "arguments": {
    "subcommand": "list",
    "repo": "namespace/project-name",
    "args": ["--state=all", "--author=@me"]
  }
}
```

### 5. Error Handling
- **"No repository"**: Add `repo` parameter with format "namespace/project"
- **"Authentication required"**: User needs to run `glab auth login`
- **"Not found"**: Check if the repository path is correct

### 6. Prompts for Common Tasks
Use the available prompts for guided workflows:
- `my-mrs`: Quick check of user's merge requests
- `daily-standup`: Gather activity for standup meetings
- `create-mr`: Step-by-step MR creation
- `review-pipeline`: Check CI/CD status

## Integration with Time Tracking
This MCP server is designed to work with intelligent time tracking systems:

1. **MR-based time entries**: Use MR numbers and titles for time entries
2. **Activity tracking**: Monitor commits, reviews, and pipeline fixes
3. **Project mapping**: Map GitLab projects to time tracking projects
4. **Automatic categorization**: Use labels and MR metadata for categorizing work

## Repository Naming Patterns
Common patterns across GitLab instances:
- `team/project-name`
- `department/service-name`
- `shared/library-name`
- `username/personal-project`

Always use the full path including namespace when specifying repositories.