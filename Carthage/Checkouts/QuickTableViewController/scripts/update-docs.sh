#!/bin/sh

cd docs && pwd

if [ "${TRAVIS_BRANCH}" = "master" ] && [ -n "$DANGER_GITHUB_API_TOKEN" ]; then
  echo "Updating gh-pages"
  git remote add upstream "https://${GH_PAGES_GITHUB_API_TOKEN}@github.com/bcylin/QuickTableViewController.git"
  git push --quiet upstream HEAD:gh-pages
  git remote remove upstream
else
  echo "Skip gh-pages updates on ${TRAVIS_BRANCH}"
fi

cd -
