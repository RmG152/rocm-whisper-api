#!/bin/bash

#########################################################
# Create Release Script
#
# Usage: ./scripts/create-release.sh v0.2.0
#
# This script automates the release process by:
# 1. Updating version in app/__init__.py
# 2. Creating a git commit with version bump
# 3. Creating a git tag
# 4. Pushing changes to GitHub
#########################################################

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
write_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

write_error() {
    echo -e "${RED}❌ $1${NC}"
}

write_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

write_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Validate version parameter
VERSION=${1:-}

if [ -z "$VERSION" ]; then
    write_error "Version not specified"
    write_info "Usage: ./scripts/create-release.sh v0.2.0"
    exit 1
fi

# Validate version format
if ! [[ $VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    write_error "Invalid version format: $VERSION"
    write_info "Expected format: v0.2.0, v1.0.0, etc."
    exit 1
fi

# Extract version number without 'v' prefix
VERSION_NUMBER=${VERSION#v}

echo ""
echo -e "${CYAN}🚀 Creating release: $VERSION${NC}"
echo ""

# Step 1: Update version in __init__.py
write_info "Step 1: Updating version in app/__init__.py"
INIT_FILE="app/__init__.py"

if [ ! -f "$INIT_FILE" ]; then
    write_error "File not found: $INIT_FILE"
    exit 1
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/__version__ = \".*\"/__version__ = \"$VERSION_NUMBER\"/" "$INIT_FILE"
else
    # Linux and others
    sed -i "s/__version__ = \".*\"/__version__ = \"$VERSION_NUMBER\"/" "$INIT_FILE"
fi

if [ $? -ne 0 ]; then
    write_error "Failed to update version"
    exit 1
fi

write_success "Version updated to $VERSION_NUMBER"

# Step 2: Add and commit changes
write_info "Step 2: Creating git commit"

git add "$INIT_FILE"
if [ $? -ne 0 ]; then
    write_error "Failed to add file to git"
    exit 1
fi

git commit -m "chore: bump version to $VERSION_NUMBER"
if [ $? -ne 0 ]; then
    write_error "Failed to create commit"
    exit 1
fi

write_success "Commit created"

# Step 3: Create git tag
write_info "Step 3: Creating git tag"

git tag -a "$VERSION" -m "Release version $VERSION_NUMBER"
if [ $? -ne 0 ]; then
    write_error "Tag creation failed"
    write_warning "Rolling back commit..."
    git reset HEAD~1
    exit 1
fi

write_success "Tag $VERSION created"

# Step 4: Push to GitHub
write_info "Step 4: Pushing changes to GitHub"

write_info "Pushing main branch..."
git push origin main
if [ $? -ne 0 ]; then
    write_error "Failed to push main branch"
    exit 1
fi

write_info "Pushing tag..."
git push origin "$VERSION"
if [ $? -ne 0 ]; then
    write_error "Failed to push tag"
    write_warning "You may need to manually push:"
    write_info "  git push origin $VERSION"
    exit 1
fi

write_success "Push completed"

echo ""
echo -e "${GREEN}✨ Release $VERSION ready!${NC}"
write_info "GitHub Actions will automatically create the release in a few moments."
write_info "Check your releases at: https://github.com/$(git config --get remote.origin.url | sed -E 's/.*github.com[:/](.*\/.*).git/\1/')/releases"
echo ""
