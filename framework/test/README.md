Testing and analysis
--------------------

## CI testing
CI testing is intended to catch major breakages. It does not guarantee
reproducibility of all bugs.

See [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) for the set of
tests that currently run in CI.

## Pre-release testing
Before making a new release, make sure all of the following are true. See
*Local testing* below for instructions.

1. All tests running in CI pass.

2. All bugs are reproducible without failing tests, when running all tests (-A).

3. Code coverage analysis succeeds for all bugs (modulo documented issues).

4. Mutation analysis succeeds for all bugs (modulo documented issues).

## Scripts

* `test.include`: Constants and helper functions for test scripts.

* `get_stats.sh`: Compute code-level stats for all bugs or a subset.

* `test_bug_mining.sh`: Tests the
  [bug-mining](https://github.com/rjust/defects4j/blob/master/framework/bug-mining) infrastructure.

* `test_coverage_cmd.sh`: Tests the
  [coverage](https://github.com/rjust/defects4j/blob/master/framework/bin/d4j/d4j-coverage) command.

* `test_export_command.sh`: Tests the
  [export](https://github.com/rjust/defects4j/blob/master/framework/bin/d4j/d4j-export) command.

* `test_fix_test_suite.sh`: Tests the
  [fix_test_suite.pl](https://github.com/rjust/defects4j/blob/master/framework/util/fix_test_suite.pl) script.

* `test_gen_tests.sh`: Tests the
  [gen_tests.pl](https://github.com/rjust/defects4j/blob/master/framework/bin/gen_tests.pl) script.
  Specifically, this script tests the integration of all supported test
  generators and the compatibility of the generated test suites with the
  coverage, mutation, and bug detection analyses.

* `test_mutation_analysis.sh`: Tests various options for the mutation analysis
  on a small sample of bugs.

* `test_mutation_cmd.sh`: Tests the
  [mutation](https://github.com/rjust/defects4j/blob/master/framework/bin/d4j/d4j-mutation) command.

* `test_sanity_check.sh`: Checks out each buggy and fixed project version and
  checks for compilation and required properties.

* `test_tutorial.sh`: Runs the tutorial described in the top-level
   [README](https://github.com/rjust/defects4j#using-defects4j).

* `test_verify_bugs.sh`: Reproduces a bug, or a set of bugs, and verifies that
   the observed set of triggering tests matches the expected set of triggering
   tests.

## Local testing
Some tests take a long time to run and usually only need to be run for major
version updates (e.g., bumping the Java version, adding new defects, or
upgrading external tools) or large-scale refactorings.

Reproducing all bugs and running mutation analysis on all bugs are the most
time-consuming test.

To speed it up long-running tests, we use GNU parallel (`-j` gives the number of
parallel processes):

### Reproducing all bugs with all tests (parallel)
```
./jobs_cmd.pl ./test_verify_bugs.sh -A | shuf | parallel -j20 --progress
```
Reproducing all bugs (20 jobs in parallel) takes ~90min.

When upgrading Defects4J it is helpful to drop the `-A` flag at first for
efficiency. (Reduces runtime to ~50min). After fixing any issues, add the
`-A` flag back in to test for full reproducibility with all tests.

### Code coverage analysis for all bugs (parallel)
```
./jobs_cmd.pl ./test_coverage_cmd.sh | shuf | parallel -j20 --progress
```
Running code coverage on all bugs (20 jobs in parallel) takes ~30min.

### Code-level stats for all bugs (parallel)
```
./jobs_cmd.pl ./get_stats.sh | shuf | parallel -j20 --progress
```
Obtaining code-level stats for all bugs (20 jobs in parallel) takes ~45min.

### Mutation analysis for all bugs (parallel)
```
./jobs_cmd.pl ./test_mutation_cmd.sh | shuf | parallel -j20 --progress
```
Running mutation analysis on all bugs (20 jobs in parallel) takes up to ~24h.

TODO: A few (Closure) jobs have a very long analysis time. (All but a hand full
of jobs finish within 14 hours.) We should prioritize these long jobs in the
shuffled job list to make sure they run early in parallel to many smaller jobs.

### Export command and exported properties
```
./test_export_command.sh
```
TODO: We should be able to run this in parallel.
