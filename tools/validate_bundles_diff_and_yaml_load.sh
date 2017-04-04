#!/bin/bash -ex

# Expect the only difference across these bundles to be source/openstack-origin
# This check is not complete or perfect, but will catch many variances.
base_comparison_bundle=bundle-mitaka.yaml
allowable_diff="source|options|origin|yaml"
for b in bundle-ocata.yaml bundle-newton.yaml; do
  if diff -Naur $b $base_comparison_bundle | egrep '^(\+|\-)' | egrep -v "$allowable_diff"; then
    echo "FAIL: $b:$base_comparison_bundle comparison NOT ok (too much diff)"
    exit 1
  fi
done

## s390x bundle file comparisons
base_comparison_bundle=bundle-mitaka-s390x.yaml
for b in bundle-ocata-s390x.yaml bundle-newton-s390x.yaml; do
  if diff -Naur $b $base_comparison_bundle | egrep '^(\+|\-)' | egrep -v "$allowable_diff"; then
    echo "FAIL: $b:$base_comparison_bundle comparison NOT ok (too much diff)"
    exit 1
  fi
done

# Basic yaml syntax check
bundles=$(find . -name "bundle*.yaml")
for bundle in $bundles; do
    /usr/bin/env python -c 'import yaml,sys;yaml.safe_load(sys.stdin)' < $bundle
done
