# defects4j_PIT

Defects4j courtesy of René Just.<br/>
This is a streamlined README with notes on changes and additional scripts only. See comprehensive README of defects4j here: https://github.com/rjust/defects4j/blob/master/README.md <br/>
<br/>
This framework has integrated the PIT mutation tool into the existing defects4j framework. It has also made changes to existing MAJOR mutation scripts to allow MAJOR mutation to operate at a test method level. A script which also identifies the triggering tests of a test suite has been created, once again this operates at a test method level opposed to the existing test class level.

# Setting up Defects4J

## Requirements

 - Java 1.8 (version 1.5.0 and older requires Java 1.7)
 - Git >= 1.9
 - SVN >= 1.8
 - Perl >= 5.0.12

#### Java version
All bugs have been reproduced and triggering tests verified, using the latest
version of Java 1.8.
Note that using Java 1.9+ might result in unexpected failing tests on a fixed
program version. 

#### Perl dependencies
All required Perl modules are listed in `cpanfile`. On many Unix platforms,
these required Perl modules are installed by default. If this is not the case,
you can use cpan (or a cpan wrapper) to install them. For example, if you have
cpanm installed, you can automatically install all modules by running:
`cpanm --installdeps .`

#### Timezone
Defects4J generates and executes tests in the timezone `America/Los_Angeles`.
If you are using the bugs outside of the Defects4J framework, set the `TZ`
environment variable to `America/Los_Angeles` and export it.

## Steps to set up Defects4J - PIT

1. Clone Defects4J:
    - `git clone https://github.com/SteGaff7/Mutant_Fault_Coupling.git`

2. Initialize Defects4J (download the project repositories and external libraries, which are not included in the git repository for size purposes and to avoid redundancies):
    - `cd defects4j_PIT`
    - `./init.sh`

3. Add Defects4J's executables to your PATH:
    - `export PATH=$PATH:"path2defects4j"/framework/bin`

4. Check installation:
    - `defects4j info -p Lang`

On some platforms such as Windows, you might need to use `perl "fullpath"\defects4j`
where these instructions say to use `defects4j`.


## Using defects4j_PIT

These scripts were created/adapated purely for research purpose and at times contain redundant code, are not the most efficient and are quite "hacky". Although they provide a means to implement the changes outlined above. Some redundant options are still available but should be avoided to ensure scripts work correctly. These redundant options, redundant lines and inefficient workarounds may be removed in time for a more optimal integreation into the framework.

### PIT:

**run_pit.pl** - Runs PIT mutation analysis on a bug with test suite in dir specified<br/>
Adapted from run_mutation.pl - some redundant lines of code and redundant command line options<br/>
<br/>
run_pit.pl [-p project] [-v version] [-t tmp_dir] [-o out_dir] [-d test_suite_dir]<br/>
<br/>
`run_pit.pl -p Time -v 1f -t scratch/tmp_dir -o mutation_results -d test_suites/fixed_suties/Time/evosuite/2`<br/>
<br/>
Redundant options - [-f], [-A], [-i], [-m]
<br/>

**run_pit_dev.pl** - Runs PIT mutation analysis on a bug with the developer test suite<br/>
Adapted from run_mutation.pl - some redundant lines of code and redundant command line options<br/>
<br/>
run_pit_dev.pl [-p project] [-v version] [-t tmp_dir] [-o out_dir]<br/>
<br/>
`run_pit_dev.pl -p Time -v 1f -t scratch/tmp_dir -o mutation_results`<br/>
<br/>
Redundant options - [-f], [-A], [-i], [-d], [-m]

### MAJOR:

**d4j-mutation2** - Runs MAJOR mutation analysis on a checked out bug with a specified test suite and file containing list of test methods. The current defects4j mutation command runs MAJOR mutation on a test suite at test class level or with one test method if -t option is used. This script runs MAJOR mutation with all test methods and outputs each test method to it's own kill map in specified output directory<br/>
<br/>
defects4j mutation2 [-p project] [-v version] [-g generator] [-n seed] [-t placeholder] [-s test_suite] [-a test_methods_file] [-w work_dir] [-o out_dir] <br/>
<br/>
`defects4j mutation2 -p Time -v 1f -g evosuite -n 1 -t x::x -s test_suites/fixed_suties/Time/evosuite/2/Time-1f.tar.bz2 -a MAJOR_suites_test_methods/gen_suites/Time/evosuite/1/test_methods.txt -w . -o mutation_results`<br/>
<br/>
Notes on command options:<br/>
- g - the generator that created this test suite, used for output path
- n - the seed used for this suite generation, used for output path
- t - simply a placeholder that must be present in form x::x
- s - test suite to use
- a - file that contains a list of test methods in format found in "MAJOR_suites_test_methods" directory
<br/>
Redundant options - [-r], [-s], [-i], [-e] <br/>
<br/>

**d4j-mutation3** - Runs MAJOR mutation analysis on a checked out bug with the developer test suite and file containing list of developer test methods. The current defects4j mutation command runs MAJOR mutation on a test suite at test class level or with one test method if -t option is used. This script runs MAJOR mutation with all test methods and outputs each test method to it's own kill map in specified output directory<br/>
<br/>
defects4j mutation3 [-p project] [-v version] [-t placeholder] [-a test_methods_file] [-w work_dir] [-o out_dir] <br/>
<br/>
`defects4j mutation3 -p Time -v 1f -t x::x -a MAJOR_suites_test_methods/dev_suites/Time/evosuite/1/dev_test_methods.txt -w . -o mutation_results`<br/>
<br/>
Redundant options - [-r], [-s], [-i], [-e] <br/>
<br/>

### Triggering Tests:

**run_triggering_test_identification.pl** - Identifies triggering **test methods** of a test suite of a specified bug. Output to a .properties file in the specified out_dir.<br/>
<br/>
run_triggering_test_identification.pl [-p project] [-v version] [-o out_dir] [-d test_suite_dir]<br/>
<br/>
`run_triggering_test_identification.pl -p Chart -v 11f -o triggering_tests -d test_suites/fixed_suties/Chart/evosuite/5`<br/>
<br/>
Redundant options - [-f], [-D], [-t]<br/>

## Modified Defects4j Files:

Each projects.build.xm file<br/>
Defects4j.build.xml file<br/>
framework/lib -- has new jar files<br/>
framework/core/Mutation<br/>
framework/core/Project<br/>
framework/core/Util<br/>
framework/bin/ ++run_pit.pl<br/>
framework/bin/ ++run_pit_dev.pl<br/>
framework/bin/ ++run_triggering_test_identification.pl<br/>
framework/bin/defects4j<br/>
framework/bin/d4j/ ++d4j-mutation2<br/>
framework/bin/d4j/ ++d4j-mutation3<br/>
