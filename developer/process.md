# Upgrade Steps

## Build Issues
Most build issues were due to the Java Version being deprecated. The steps for
these were:
* Use defects4j checkout to see the directory structure. Start at the build.xml
  file and follow the chain down, grepping for things that might be version
  numbers
* Once you find the fix, add a replacement rule to test_verify_bugs.sh. The
  needed rule might be different for different versions of the same project

## Test Issues
Test issues mean that source code is compiling, but there are tests that either
fail to compile or exhibit different runtime behavior under Java 11. The code
can be checked out using defects4j checkout, and based on the type of issue we
can either exclude a test by updating the appropriate failing_tests file or make
updates to the code. So far, we have only done exclusion. I looked into trying
to automate this process using update_failing_tests.py, which takes the output
of test_verify_bugs.sh as an input, but did not get very far.
