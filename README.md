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

## Using defects4j_PIT

These scripts were created/adapated purely for research purpose and at times contain redundant code, are not the most efficient and are quite "hacky". Although they provide a means to implement the changes outlined above. Some redundant options are still available but should be avoided to ensure scripts work correctly. These redundant options, redundant lines and inefficient workarounds may be removed in time for a more optimal integreation into the framework.

### PIT:

**run_pit.pl** - Runs PIT mutation analysis on a bug with test suite in dir specified<br/>
Adapted from run_mutation.pl - some redundant lines of code and redundant command line options<br/>
<br/>
run_pit.pl [-p project] [-v version][-o out_dir] [-d test_suite_dir]<br/>
<br/>
`run_pit.pl -p Time -v 1f -o mutation_results -d test_suites/fixed_suties/Time/evosuite/2`<br/>
<br/>
Redundant options - [-f], [-A], [-i], [-m], [-t]
<br/>

**run_pit_dev.pl** - Runs PIT mutation analysis on a bug with the developer test suite<br/>
Adapted from run_mutation.pl - some redundant lines of code and redundant command line options<br/>
<br/>
run_pit_dev.pl [-p project] [-v version] [-o out_dir]<br/>
<br/>
`run_pit_dev.pl -p Time -v 1f -o mutation_results`<br/>
<br/>
Redundant options - [-f], [-A], [-i], [-d], [-m], [-t]


## Modified Defects4j Files:

Each projects.build.xm file<br/>
Defects4j.build.xml file<br/>
framework/lib -- has new jar files<br/>
framework/core/Mutation<br/>
framework/core/Project<br/>
framework/core/Util<br/>
framework/bin/ ++run_pit.pl<br/>
framework/bin/ ++run_pit_dev.pl<br/>
