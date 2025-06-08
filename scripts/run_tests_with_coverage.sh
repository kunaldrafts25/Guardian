#!/bin/bash

# Run tests with coverage
flutter test --coverage

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Open the report in the default browser
if [[ "$OSTYPE" == "darwin"* ]]; then
  open coverage/html/index.html
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  xdg-open coverage/html/index.html
elif [[ "$OSTYPE" == "msys" ]]; then
  start coverage/html/index.html
fi
