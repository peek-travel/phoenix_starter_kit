# Contributing to Phoenix Starter Kit

Thank you for your interest in contributing to the Phoenix Starter Kit for Peek Pro Apps! This document provides guidelines and instructions for contributing.

## Getting Started

### Prerequisites

- Elixir 1.14 or higher
- Erlang/OTP 25 or higher
- PostgreSQL 12 or higher
- Node.js 18 or higher (for asset compilation)

### Setting Up Your Development Environment

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/phoenix_starter_kit.git
   cd phoenix_starter_kit
   ```

3. Install dependencies:
   ```bash
   mix deps.get
   npm install --prefix assets
   ```

4. Set up your database:
   ```bash
   mix ecto.setup
   ```

5. Run the test suite to ensure everything is working:
   ```bash
   bin/check
   ```

## Development Workflow

### Running the Application

Start the Phoenix server:
```bash
bin/server
```

The application will be available at `http://localhost:4000`.

### Running Tests

We maintain 100% test coverage. Before submitting a PR, ensure all tests pass:

```bash
# Run all tests with coverage
mix coveralls.lcov

# Run tests in watch mode during development
mix test.watch

# Run specific test file
mix test test/path/to/test_file.exs

# Run specific test by line number
mix test test/path/to/test_file.exs:42
```

### Code Quality

We use several tools to maintain code quality:

```bash
# Format code (required before committing)
mix format

# Run static analysis
mix credo

# Run all checks (format, credo, tests)
bin/check
```

## Making Changes

### Branch Naming

Use descriptive branch names:
- `feature/add-new-widget-support`
- `fix/partner-authentication-bug`
- `docs/update-deployment-guide`
- `refactor/simplify-webhook-handling`

### Commit Messages

Write clear, descriptive commit messages:

```
Add support for custom webhook events

- Implement webhook event registry
- Add tests for custom event handling
- Update documentation with examples
```

**Format:**
- First line: Brief summary (50 chars or less)
- Blank line
- Detailed description with bullet points if needed

### Code Style

- Follow the existing code style
- Run `mix format` before committing
- Keep functions small and focused
- Write descriptive variable and function names
- Add `@doc` and `@moduledoc` for public functions and modules
- Use pattern matching and guards effectively

### Testing Guidelines

- Write tests for all new functionality
- Update existing tests when modifying behavior
- Use descriptive test names: `test "creates partner when installation webhook received"`
- Follow the Arrange-Act-Assert pattern
- Mock external dependencies appropriately
- Maintain 100% test coverage (or justify exceptions)

### Documentation

- Update README.md if adding new features or changing setup
- Update architecture.md if changing module boundaries or data models
- Add inline comments for complex logic
- Include examples in function documentation
- Update .env.example if adding new environment variables

## Pull Request Process

### Before Submitting

1. Ensure all tests pass: `bin/check`
2. Update documentation as needed
3. Add yourself to the contributors list (if not already there)
4. Rebase on the latest main branch
5. Ensure your branch has a clear, linear history

### Submitting a PR

1. Push your branch to your fork
2. Open a Pull Request against the `main` branch
3. Fill out the PR template completely
4. Link any related issues
5. Request review from maintainers

### PR Title Format

Use conventional commit format:
- `feat: Add webhook retry mechanism`
- `fix: Resolve partner authentication timeout`
- `docs: Update deployment instructions`
- `refactor: Simplify partner user context`
- `test: Add integration tests for webhooks`
- `chore: Update dependencies`

### PR Description

Include:
- **What**: What changes does this PR introduce?
- **Why**: Why are these changes needed?
- **How**: How were the changes implemented?
- **Testing**: How was this tested?
- **Screenshots**: If UI changes, include before/after screenshots
- **Breaking Changes**: List any breaking changes
- **Migration Notes**: Any special deployment or migration steps

### Review Process

- At least one maintainer approval required
- All CI checks must pass
- Address all review comments
- Keep the PR focused and reasonably sized
- Be responsive to feedback

## Types of Contributions

### Bug Reports

When filing a bug report, include:
- Clear, descriptive title
- Steps to reproduce
- Expected behavior
- Actual behavior
- Environment details (Elixir version, OS, etc.)
- Relevant logs or error messages
- Screenshots if applicable

### Feature Requests

When proposing a feature:
- Explain the use case
- Describe the proposed solution
- Consider alternatives
- Discuss potential impact on existing functionality
- Be open to feedback and iteration

### Documentation Improvements

Documentation contributions are highly valued:
- Fix typos and grammar
- Clarify confusing sections
- Add examples
- Improve organization
- Update outdated information

### Code Contributions

Areas where contributions are especially welcome:
- Additional webhook handlers
- Improved error handling
- Performance optimizations
- Additional test coverage
- UI/UX improvements
- Accessibility enhancements

## Architecture Guidelines

### Context Boundaries

- Keep contexts focused and cohesive
- Avoid circular dependencies between contexts
- Use public functions as the context API
- Keep implementation details private

### Database Design

- Use UUIDs for primary keys
- Add appropriate indexes
- Write reversible migrations
- Include migration tests for complex changes

### LiveView Best Practices

- Keep LiveView modules focused
- Extract reusable components
- Handle errors gracefully
- Optimize for minimal data over the wire
- Use temporary assigns for large data

### Security Considerations

- Never commit secrets or credentials
- Validate all user input
- Use parameterized queries (Ecto does this by default)
- Implement proper authorization checks
- Follow OWASP guidelines

## Getting Help

- **Questions**: Open a GitHub Discussion
- **Bugs**: File a GitHub Issue
- **Security Issues**: Email security@peek.com (do not file public issues)
- **General Chat**: Join our community Slack (link TBD)

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive environment for all contributors, regardless of background or identity.

### Expected Behavior

- Be respectful and considerate
- Welcome newcomers and help them get started
- Provide constructive feedback
- Focus on what's best for the community
- Show empathy towards others

### Unacceptable Behavior

- Harassment or discrimination of any kind
- Trolling or insulting comments
- Personal or political attacks
- Publishing others' private information
- Other conduct inappropriate in a professional setting

### Enforcement

Violations may result in temporary or permanent ban from the project. Report issues to the maintainers.

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (see LICENSE file).

## Recognition

Contributors will be recognized in:
- The project README
- Release notes for significant contributions
- Our contributors page (coming soon)

## Questions?

Don't hesitate to ask questions! We're here to help. Open a GitHub Discussion or reach out to the maintainers.

Thank you for contributing to Phoenix Starter Kit! 🎉

