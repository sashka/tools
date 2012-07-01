#!/bin/bash
set -e

echo "Building debian package..."

# Getting version
GITVERSION=$(git describe --tags --long --abbrev=10)
GITVERSION=$(echo "${GITVERSION}" | sed 's,-g,-,') # remove "g" from git tag
DEBVERSION=$(echo "${GITVERSION}" | sed 's,^v,,') # remove leading "v" (e.g. v2.2.0 -> 2.2.0)

# Just in case there were previous build, restoring debian/changelog.
git checkout debian/changelog

if [ -z "$NAME" -o -z "$EMAIL" ]; then
  echo Please define NAME and EMAIL environment variables.
  exit 1
fi

dch -v ${DEBVERSION} "Update to revision ${GITVERSION}"
dpkg-buildpackage -us -uc -sa -si -rfakeroot

