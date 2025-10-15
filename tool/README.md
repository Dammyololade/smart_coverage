# Coverage Badge Automation

This directory contains scripts to automate coverage badge updates for the Smart Coverage project.

## 🚀 Automated Solutions

### 1. GitHub Actions (CI/CD) - **Recommended for Teams**

The `.github/workflows/coverage.yml` workflow automatically:
- ✅ Runs tests and generates coverage on every push/PR
- 📊 Calculates coverage percentage
- 🎨 Generates and commits updated badge to `main` branch
- 💬 Comments coverage percentage on PRs
- 📤 Uploads HTML coverage reports as artifacts

**Setup:**
1. The workflow is already configured in `.github/workflows/coverage.yml`
2. Push to GitHub and the workflow will run automatically
3. Badge updates on every merge to `main`

**Note:** The workflow needs write permissions. Add this to your repository settings:
- Go to Settings → Actions → General → Workflow permissions
- Select "Read and write permissions"

### 2. Local Bash Script - **Quick Manual Updates**

Use `tool/update_coverage_badge.sh` for local badge updates:

```bash
# Make it executable (already done)
chmod +x tool/update_coverage_badge.sh

# Run it
./tool/update_coverage_badge.sh
```

**Features:**
- Runs tests with coverage
- Calculates coverage percentage
- Generates color-coded badge
- Works on macOS and Linux

### 3. Dart Script - **Cross-Platform**

Use `tool/update_coverage_badge.dart` for a pure Dart solution:

```bash
dart run tool/update_coverage_badge.dart
```

**Benefits:**
- Works on all platforms (Windows, macOS, Linux)
- No bash dependencies
- Color-coded feedback
- Detailed coverage breakdown

### 4. Git Pre-Commit Hook - **Automatic Local Updates**

Install the pre-commit hook to auto-update badge before commits:

```bash
# Install the hook
cp tool/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**How it works:**
- Triggers when you commit changes to test or source files
- Automatically runs coverage and updates badge
- Adds updated badge to your commit

## 🎨 Badge Color Scheme

The badge color automatically adjusts based on coverage:

| Coverage | Color | Status |
|----------|-------|--------|
| ≥90% | 🟢 Bright Green (#44cc11) | Excellent |
| ≥80% | 🟢 Green (#97ca00) | Good |
| ≥70% | 🟡 Yellow (#dfb317) | Acceptable |
| ≥60% | 🟠 Orange (#fe7d37) | Needs Improvement |
| <60% | 🔴 Red (#e05d44) | Poor |

## 📋 Recommended Workflow

### For Individual Developers

```bash
# Option 1: Manual update when needed
./tool/update_coverage_badge.sh

# Option 2: Automatic on commits
cp tool/pre-commit .git/hooks/pre-commit
# Now badge updates automatically when committing test changes
```

### For Teams

1. **Push code to GitHub**
2. **GitHub Actions runs automatically**
3. **Badge updates on main branch**
4. **PR comments show coverage changes**

## 🔧 Requirements

### For Local Scripts:
- **Dart SDK** (already installed)
- **lcov** (for bash script only):
  - macOS: `brew install lcov`
  - Ubuntu/Debian: `sudo apt-get install lcov`
  - Windows: Use the Dart script instead

### For GitHub Actions:
- No additional setup needed
- Runs in Ubuntu environment with all dependencies

## 📊 Viewing Coverage Reports

### HTML Report (Detailed View)

```bash
# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Open in browser
open coverage/html/index.html  # macOS
xdg-open coverage/html/index.html  # Linux
```

### Console Report (Quick View)

```bash
# After running coverage
lcov --summary coverage/lcov.info
```

### CI/CD Artifacts

Download HTML reports from GitHub Actions:
1. Go to Actions tab
2. Click on a workflow run
3. Download "coverage-report" artifact

## 🐛 Troubleshooting

### "lcov: command not found"

**Solution:**
```bash
# macOS
brew install lcov

# Linux
sudo apt-get install lcov

# OR use the Dart script instead
dart run tool/update_coverage_badge.dart
```

### "Permission denied" when running scripts

**Solution:**
```bash
chmod +x tool/update_coverage_badge.sh
chmod +x tool/pre-commit
```

### Badge not updating on GitHub

**Solutions:**
1. Check workflow permissions (Settings → Actions → General)
2. Verify workflow ran successfully (Actions tab)
3. Badge file must be in repository root
4. Clear browser cache to see updated badge

### Pre-commit hook not working

**Solution:**
```bash
# Reinstall the hook
cp tool/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Verify it exists
ls -la .git/hooks/pre-commit
```

## 🎯 Quick Reference

```bash
# Update badge locally (bash)
./tool/update_coverage_badge.sh

# Update badge locally (Dart)
dart run tool/update_coverage_badge.dart

# Install pre-commit hook
cp tool/pre-commit .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit

# View coverage report
genhtml coverage/lcov.info -o coverage/html && open coverage/html/index.html

# Check coverage percentage only
lcov --summary coverage/lcov.info 2>&1 | grep "lines"
```

## 💡 Tips

1. **Commit the badge:** Always commit `coverage_badge.svg` after updates
2. **CI is automatic:** GitHub Actions handles badge updates on main branch
3. **Local testing:** Use local scripts before pushing to verify coverage
4. **Pre-commit hook:** Great for ensuring badge is always up-to-date
5. **Coverage threshold:** Aim for ≥80% for the green badge!

## 📝 Adding Badge to README

The badge is already in your README.md:

```markdown
![coverage][coverage_badge]

[coverage_badge]: coverage_badge.svg
```

Make sure `coverage_badge.svg` is in the repository root!

