#!/bin/bash

# Script to run before each commit

dart format .
dart analyze .
dart run test