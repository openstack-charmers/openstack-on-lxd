#!/bin/bash -ex

# Expect the only difference across these bundles to be source/openstack-origin
# This check is not complete or perfect, but will catch many variances.
base_comparison_bundle=bundle-xenial-mitaka.yaml
allowable_diff="force-raw-images:|source:|options:|series:|openstack-origin:|^\-\-\-|^\+\+\+"
for b in bundle-xenial-queens.yaml bundle-xenial-pike.yaml bundle-xenial-ocata.yaml bundle-xenial-newton.yaml; do
  if diff -Naur $b $base_comparison_bundle | egrep '^(\+|\-)' | egrep -v "$allowable_diff"; then
    echo "FAIL: $b:$base_comparison_bundle comparison NOT ok (too much diff)"
    exit 1
  fi
done

## s390x bundle file comparisons
base_comparison_bundle=bundle-xenial-mitaka-s390x.yaml
for b in bundle-xenial-pike-s390x.yaml bundle-xenial-ocata-s390x.yaml bundle-xenial-newton-s390x.yaml; do
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
