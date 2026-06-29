---
name: code-review
description: Perform a structured, high-quality review of code changes, identifying potential bugs, design issues, and performance optimizations.
---

# Code Review Skill

Use this skill whenever the user requests a code review, feedback on a pull request, or a review of specific changes in the workspace.

## Guidelines for Performing Code Reviews

### 1. Context & Scope Gathering

- Identify the files and lines that changed.
- Determine if the review is for:
  - Staged changes (`git diff --staged`)
  - Unstaged/working changes (`git diff`)
  - A branch comparison (e.g., `git diff main...HEAD` or `git diff origin/main...HEAD`)
  - Specific files or directories requested by the user.
- Read through the context around the changes, not just the raw diff lines, to understand how the new code interacts with the existing system.

### 2. Key Review Dimensions

Assess the changes across the following criteria:

- **Correctness & Edge Cases**: Check for logical bugs, off-by-one errors, boundary conditions, race conditions, null references, and unhandled exceptions. Ensure proper error-handling and logging are in place.
- **Conventions & Standards**: Match the design conventions of the target codebase. For example:
  - In a backend .NET codebase, ensure classes are `sealed` by default, EF Core queries use `AsNoTracking()` where read-only, and endpoints follow the FastEndpoints pattern.
  - In a frontend React codebase, verify proper hooks usage, custom Zod v4 validation setup, and Radix UI styling patterns.
- **Design & Maintainability (DRY)**: Look for duplicated code or patterns that could be refactored into shared helpers. Check for proper decoupling and separation of concerns.
- **Performance & Resource Management**: Identify N+1 query patterns, missing async/await calls, excessive object allocation in hot paths, and potential memory leaks. Verify that resources (connections, files) are correctly disposed of.
- **Security**: Scan for SQL injection, cross-site scripting (XSS), missing authorization checks, exposed sensitive information/secrets, or insecure input validation.
- **Readability**: Ensure variable and function names are clear, comments explain *why* something is done rather than *what* is done, and formatting is consistent.

### 3. Feedback Structure and Formatting

Format your response to the user with a clean, structured hierarchy:

#### Summary of Changes

- Provide a brief 1-2 sentence overview of what the changes accomplish.

#### Review Findings

Categorize your findings by severity using the following headers and emojis:

- **🔴 Critical / Defect**: Blocking bugs, security vulnerabilities, or logic errors that will cause incorrect behavior.
- **🟡 Important / Design**: Architectural concerns, DRY violations, convention mismatches, or performance issues.
- **🟢 Minor / Polish**: Small suggestions for readability, renaming, minor styling improvements, or formatting.
- **💙 Praise**: Highlight exceptionally clean code, clever solutions, or solid architectural patterns.

#### Actionable Suggestions

For any issues found, provide specific code blocks or git diffs demonstrating the proposed solution. Explain the rationale behind the recommendation clearly so the user understands the benefit.

Example:

```diff
- public class UserService {
+ public sealed class UserService {
```
