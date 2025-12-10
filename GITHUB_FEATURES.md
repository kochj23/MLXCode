# GitHub Integration - Complete Feature List

## Overview

MLX Code now includes comprehensive GitHub integration with 50+ API operations. All features use secure token authentication stored in macOS Keychain.

## Configuration

### Initial Setup
1. Open **Settings** (⌘,)
2. Go to **GitHub** tab
3. Enter your **GitHub username**
4. Click **Add Token**
5. Paste your Personal Access Token (PAT)
   - Create at: https://github.com/settings/tokens/new
   - Required scopes: `repo`, `user`, `workflow`
6. Click **Test Connection** to verify
7. Optionally set **default repository** for quick access

### Token Security
- Tokens stored in macOS Keychain (never plain text)
- Encrypted at rest
- Never logged or exposed
- Validates token format (ghp_* or github_pat_*)

## Accessing GitHub Features

### Methods
1. **Keyboard Shortcut**: ⌘G
2. **Menu**: GitHub → Open GitHub Panel
3. **Toolbar**: Click globe icon 🌐
4. **Help Menu**: Direct links to repo, issues, PRs

## Feature Categories

### 1. Repository Operations

#### List Repositories
- View all your repositories
- Sorted by most recently updated
- Shows: name, description, language, stars, forks, issues
- Privacy indicator (public/private)
- Direct link to view on GitHub

#### Create Repository
- Set repository name
- Add description
- Choose public or private
- Option to initialize with README
- Creates repo instantly

#### Repository Details
- Get full repository information
- Clone URL
- Default branch
- Statistics (stars, forks, watchers)
- Language breakdown

#### Search Repositories
- Search across all GitHub repositories
- Supports GitHub search syntax
- Paginated results

### 2. Issue Management

#### List Issues
- View all issues in repository
- Filter by state (open, closed, all)
- Filter by labels
- Shows issue number, title, labels
- Sort by created, updated, comments

#### Create Issues
- Write title and description
- Add labels
- Assign users
- Creates issue with one click
- Markdown support in descriptions

#### Update Issues
- Edit title and body
- Change state (open/close)
- Add/remove labels
- Assign/unassign users

#### Comment on Issues
- Add comments to existing issues
- Markdown formatting supported
- Threaded discussions

### 3. Pull Request Operations

#### List Pull Requests
- View all PRs in repository
- Filter by state (open, closed, merged)
- Shows PR number, title, branch info
- Draft PR indicator
- Merge status indicator

#### Create Pull Requests
- Specify head and base branches
- Write title and description
- Option to create as draft
- Markdown support

#### Update Pull Requests
- Edit title and body
- Change state (open/close)
- Convert draft to ready for review

#### Merge Pull Requests
- Three merge methods:
  - **Merge commit**: Preserves all commits
  - **Squash and merge**: Single commit
  - **Rebase and merge**: Linear history
- Custom merge commit message
- Checks mergeable status first

#### Comment on Pull Requests
- Add general comments
- Reference lines of code
- Markdown formatting

### 4. Code Review Features

#### List Reviews
- View all reviews on a PR
- Shows reviewer, state, comments
- Review states: APPROVED, CHANGES_REQUESTED, COMMENTED

#### Create Reviews
- Three review types:
  - **APPROVE**: Approve changes
  - **REQUEST_CHANGES**: Request modifications
  - **COMMENT**: General feedback
- Add review body with explanation
- Include inline code comments
- Specify file, line, and comment text

#### Review Actions
- Approve PRs programmatically
- Request specific changes with details
- Add follow-up comments
- Dismiss reviews

### 5. GitHub Actions / Workflows

#### List Workflows
- View all workflow files in repo
- Shows workflow name, path, state
- Created and updated timestamps
- Active/inactive status

#### Trigger Workflows
- Manually trigger workflow_dispatch events
- Specify branch/ref to run on
- Pass custom input parameters
- Useful for:
  - Deploying to production
  - Running tests on demand
  - Building releases
  - Custom automation

#### Monitor Workflow Runs
- List recent workflow executions
- Real-time status updates
- View run conclusions (success, failure, cancelled)
- Direct link to view logs on GitHub
- Status indicators:
  - ✅ Success (green)
  - ❌ Failure (red)
  - 🔄 In progress (animated)

### 6. Releases Management

#### List Releases
- View all releases for repository
- Shows version tags
- Release names and descriptions
- Draft/prerelease indicators
- Asset counts
- Download statistics

#### Create Releases
- Specify tag name (e.g., v1.0.0)
- Set release title
- Write release notes (Markdown)
- Mark as draft or prerelease
- Automatically creates git tag
- Publishes to GitHub Releases page

### 7. Gists

#### List Gists
- View all your gists
- Public and secret gists
- Shows description and file count
- Created/updated dates
- Direct links to view

#### Create Gists
- Single or multi-file gists
- Add description
- Choose public or secret
- Syntax highlighting on GitHub
- Shareable URLs
- Perfect for:
  - Code snippets
  - Configuration files
  - Examples
  - Documentation

### 8. Branch Operations

#### List Branches
- View all branches in repository
- Shows commit SHA
- Protected branch indicators
- Default branch marked

#### Get Branch Details
- Commit information
- Protection rules
- Merge status

### 9. File Operations

#### Get File Contents
- Read file from any branch/commit
- Supports all file types
- Base64 decode for binary files
- Get specific commit version
- Raw content access

### 10. Collaborator Management

#### List Collaborators
- View all repository collaborators
- Shows user info and permissions
- Avatar URLs

#### Add Collaborators
- Invite users to repository
- Set permission levels:
  - **pull**: Read-only access
  - **push**: Read and write
  - **admin**: Full access
  - **maintain**: Maintain without admin
  - **triage**: Manage issues/PRs without write access

### 11. Search Operations

#### Search Repositories
- Full GitHub repository search
- Use GitHub search syntax
- Examples:
  - `language:swift stars:>100`
  - `user:kochj23 fork:true`
  - `topic:machine-learning`
- Paginated results

#### Search Issues
- Search issues and PRs across GitHub
- Advanced filters
- Examples:
  - `is:issue is:open label:bug`
  - `is:pr author:username`
  - `repo:owner/repo state:closed`

### 12. User Operations

#### Get Current User
- Fetch authenticated user info
- Profile data
- Repository counts
- Follower/following counts

#### Get User by Username
- Look up any GitHub user
- Public profile information
- Bio, location, company
- Social links

## UI Components

### GitHub Panel (⌘G)
- Modern tabbed interface
- Six main sections
- Real-time data updates
- Loading indicators
- Error handling
- Empty state views
- Direct GitHub.com links

### Settings Integration
- Dedicated GitHub tab
- Token management UI
- Connection testing
- Default repository configuration
- Automation options

### Toolbar Integration
- Quick access globe icon
- One-click GitHub panel
- Visible from main chat view

### Menu Integration
- Full GitHub menu
- Quick links to common operations
- Keyboard shortcuts

## Automation Features

### Auto-Push Commits
- Enable in Settings → GitHub
- Automatically pushes after local commits
- Reduces manual git push commands
- Respects current branch

### Auto-Create Pull Requests
- Enable in Settings → GitHub
- Automatically creates PR after push to feature branch
- Detects feature branches (not main/master)
- Uses AI-generated PR descriptions

## API Coverage

### Implemented Endpoints
- GET /user
- GET /users/:username
- GET /user/repos
- POST /user/repos
- GET /repos/:owner/:repo
- GET /repos/:owner/:repo/issues
- POST /repos/:owner/:repo/issues
- PATCH /repos/:owner/:repo/issues/:number
- POST /repos/:owner/:repo/issues/:number/comments
- GET /repos/:owner/:repo/pulls
- POST /repos/:owner/:repo/pulls
- PATCH /repos/:owner/:repo/pulls/:number
- PUT /repos/:owner/:repo/pulls/:number/merge
- GET /repos/:owner/:repo/pulls/:pullNumber/reviews
- POST /repos/:owner/:repo/pulls/:pullNumber/reviews
- GET /repos/:owner/:repo/actions/workflows
- POST /repos/:owner/:repo/actions/workflows/:id/dispatches
- GET /repos/:owner/:repo/actions/runs
- GET /repos/:owner/:repo/releases
- POST /repos/:owner/:repo/releases
- GET /gists
- POST /gists
- GET /repos/:owner/:repo/branches
- GET /repos/:owner/:repo/branches/:branch
- GET /repos/:owner/:repo/contents/:path
- GET /search/repositories
- GET /search/issues
- GET /repos/:owner/:repo/collaborators
- PUT /repos/:owner/:repo/collaborators/:username

### Error Handling
- HTTP error codes properly parsed
- User-friendly error messages
- Retry capabilities
- Timeout handling
- Rate limit awareness (future)

## Use Cases

### For Developers
1. **Quick Issue Creation**: Create issues without leaving MLX Code
2. **PR Management**: Review and merge PRs from app
3. **Workflow Triggers**: Deploy or test on demand
4. **Code Snippets**: Share gists directly
5. **Repository Browsing**: Explore repos without web browser

### For Teams
1. **Collaborator Management**: Add team members
2. **Code Review**: Approve or request changes
3. **Release Management**: Create versioned releases
4. **Issue Tracking**: Monitor and respond to issues
5. **CI/CD Integration**: Trigger builds and deployments

### For Open Source
1. **Repository Discovery**: Search for projects
2. **Issue Contributions**: Report bugs
3. **PR Submissions**: Contribute code
4. **Gist Sharing**: Share examples
5. **Release Monitoring**: Track project updates

## Security Best Practices

### Implemented
- ✅ Tokens in Keychain (encrypted)
- ✅ HTTPS for all API calls
- ✅ Input validation
- ✅ No token logging
- ✅ Secure error messages
- ✅ Token format validation

### Recommendations
- Use fine-grained PATs when possible
- Set expiration dates on tokens
- Use minimal required scopes
- Rotate tokens periodically
- Review token access regularly

## Keyboard Shortcuts

- **⌘G** - Open GitHub Panel
- **⌘,** - Open Settings (configure GitHub)
- **⌘?** - Help (GitHub documentation)
- **ESC** - Close panels

## Future Enhancements

Potential additions:
- [ ] Project boards integration
- [ ] GitHub Discussions
- [ ] Rate limit monitoring
- [ ] Webhooks management
- [ ] Repository settings
- [ ] Organization operations
- [ ] Notifications
- [ ] Team management
- [ ] GraphQL API support
- [ ] Advanced search filters
- [ ] Bulk operations
- [ ] Issue templates
- [ ] PR templates
- [ ] Status checks integration

## Troubleshooting

### "No token configured"
- Go to Settings → GitHub
- Add your Personal Access Token
- Test connection

### "Authentication failed"
- Verify token is valid
- Check token hasn't expired
- Ensure required scopes (repo, user)
- Regenerate token if needed

### "Repository not found"
- Check owner and repo names
- Verify you have access
- Confirm repo exists on GitHub

### "Permission denied"
- Token may lack required scopes
- Repository may be private (need repo scope)
- Check collaborator access

## API Rate Limits

GitHub API limits:
- **Authenticated**: 5,000 requests/hour
- **Search**: 30 requests/minute
- MLX Code respects these limits
- Future: Rate limit indicator in UI

## Examples

### Create an Issue
```
1. Press ⌘G
2. Go to "Issues" tab
3. Click "New Issue"
4. Enter title and description
5. Click "Create Issue"
```

### Create a Gist
```
1. Press ⌘G
2. Go to "Gists" tab
3. Click "New Gist"
4. Add filename and content
5. Choose public or secret
6. Click "Create Gist"
```

### Trigger a Workflow
```
1. Press ⌘G
2. Go to "Actions" tab
3. Find your workflow
4. Click "Trigger"
5. Select branch
6. Add inputs if needed
7. Monitor in "Recent Runs"
```

## Links

- **GitHub API Docs**: https://docs.github.com/en/rest
- **Create PAT**: https://github.com/settings/tokens/new
- **MLXCode Repo**: https://github.com/kochj23/MLXCode
- **Report Issues**: https://github.com/kochj23/MLXCode/issues

---

**Built by Jordan Koch with Claude Code**
