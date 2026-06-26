# Contributing to RemNote Auto Updater

First off, thank you for considering contributing to RemNote Auto Updater! It's people like you that make this tool better for everyone.

## Code of Conduct

This project and everyone participating in it is governed by respect and professionalism. By participating, you are expected to uphold this standard.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples** to demonstrate the steps
- **Describe the behavior you observed** and what you expected
- **Include screenshots** if relevant
- **Include your environment details**:
  - Windows version
  - PowerShell version (`$PSVersionTable.PSVersion`)
  - 7-Zip version
  - Script parameters used

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- **Use a clear and descriptive title**
- **Provide a detailed description** of the suggested enhancement
- **Explain why this enhancement would be useful**
- **List any alternative solutions** you've considered

### Pull Requests

1. Fork the repo and create your branch from `main`
2. Make your changes
3. Test your changes thoroughly
4. Update documentation if needed
5. Ensure your code follows the existing style
6. Write clear commit messages
7. Submit a pull request

## Development Guidelines

### PowerShell Style

- Use clear, descriptive variable names
- Add comments for complex logic
- Follow existing indentation (4 spaces)
- Use proper error handling with try/catch blocks
- Write descriptive log messages

### Testing

Before submitting a PR, please test your changes and ensure the script works. Ex:
```powershell
# Test basic functionality
.\RemNoteUpdater.ps1 -RunOnce

# Test custom paths
.\RemNoteUpdater.ps1 -RunOnce -InstallPath "C:\Test\RemNote" -TempPath "C:\Test\Temp"

# Test continuous monitoring (cancel after verification)
.\RemNoteUpdater.ps1 -CheckIntervalMinutes 1
```

### Documentation

- Update README.md if you change functionality
- Add inline comments for complex code
- Update parameter descriptions if adding new parameters

## Questions?

Feel free to open an issue with your question or reach out via the RemNote community Discord.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
