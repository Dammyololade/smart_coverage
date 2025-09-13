#!/bin/bash

# Useful script to run all the required check before raising a PR

# Exit immediately if a command exits with a non-zero status
set -e

# Run build runner
echo -e "${BLUE}🔧 Running build runner...${NC}"
melos run build_runner:build

# Run analyze
echo -e "${BLUE}🔍 Running analyze...${NC}"
melos run analyze

# Run test coverage
echo -e "${BLUE}🧪 Running test coverage...${NC}"
melos run test:coverage:filtered:full

