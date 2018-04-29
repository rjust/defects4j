# Patch Minimization Guide

This document includes:

1. instructions to run patch minimization related scripts
2. instructions to perform patch minimization, along with justifications and code examples 
3. guidelines of ideal minimized patches


## Instructions to Using the Framework

### Meld
By default, running `./minimize-patch .pl -p <project> -w <branch> -b <bug.id>` will automatically open up meld.  Meld is a user-friendly editor to visualize the changes introduced in the patch.  Visit [Meld](http://meldmerge.org/help/) for further instructions to download.

### Other Editors
Feel free to use any other editors.  Reference [The Secret of Editing Hunks](http://joaquin.windmuller.ca/2011/11/16/selectively-select-changes-to-commit-with-git-or-imma-edit-your-hunk) at the bottom of the page to mannually edit patches.  REMINDER: some editors, such as Atom, will automatically remove the spaces at the end of the file, causing the patch file to be corrupted.

### Restoring Original Patch
Delete corresponding patch under `patch` directory, and re-run `./initialize-revision.pl -p <project> -w <branch> -b <bug.id>`

##Instructions to Perform Patch Minimization

### Understanding the Bug and Narrowing Down the Scope
Read corresponding stack trace under `trigger_tests` directory to get a rough idea of how to re-introduce the bug. Determine the failed test (in `package.className::methodName`format). Delete irrelevant changes(diffs) -- any diff that do not appear in the stack trace

Commit messages, comments, and sometimes the messages included in exception can also be helpful.


### Common Types of Bug Fix and Proposed Rules to Disambiguate Results
1. Non-functional changes introduced to fixed version that need to be removed:
	* White spaces
	* Tabs
	* New lines
	* Comments
		* Justification: Comments could be considered as part of the bug fix: a developer may 		want to associate a comment with a bug fix and therefore include it in the pure bug-		fixing patch; a researcher may want to ignore comments when reasoning about the 		complexity of a bug-fixing patch. Since here, we are interested in minimizing the code 		to create a minimal bug/ minimal fix, we can remove all the comments and documentation 		elements from the code
	* Example: Collections 71 contains tab changes that caused unnecessarily huge patch. [Collections 71 non-minimized](https://github.com/ypzheng/defects4j/blob/merge-bug-mining-into-master/framework/bug-mining/code-example/col.71.preminimized.patch) vs. [Collections 71 minimized](https://github.com/ypzheng/defects4j/blob/merge-bug-mining-into-master/framework/bug-mining/code-example/col.71.minimized.patch)

	* Sementically equivalent changes should be removed 
		* Justification: The only changes are in the style of programming or a programmer’s 		preference of writing them in one way as opposed to another. 
		* Example: `byte b[]` and `byte[] b` are the same
			```diff
			-      public int read(byte b[], final int off, final int len) throws IOException
			+      public int read(byte[] b, final int off, final int len) throws IOException
			```
		* Example: The two if statements are sementically equivalent. In fact, this is also 		an 	example of refactoring.
			```diff
			-      if (getInclude() != null && key.equalsIgnoreCase(getInclude())) 
			+      String includeProperty = getInclude();
			+      if (includeProperty != null && key.equalsIgnoreCase(includeProperty)) 
			```
			
2. Code changes introduced to fixed version that may or __may not__ be removed
	* Import statements: if an import statement is added/deleted in the fixed version, remove 	the change.
		* Justification: Although removing changes involving import statements might create new 		warnings of “unused imports”, import 		statements would not communicate anything about the bug or the bug fix. It would only 		be necessary to support functions. It is also worth noting that these import statements 		could be completely removed by using the fully qualified function names. Hence, in some 		sense the import statements can be considered as a refactoring operation.
	* @override statements: if `@override` is added to a pre-existing method and there are no 	changes made to that specific method in fixed version, remove the change.  Otherwise, __do 	not__ 	remove the statement.
		* [TODO]: Justification, example of removable vs non-removable
	* Unused variables/functions: removal of unused variables and definition of uncalled 	functions in fixed version should be removed from the patch.
		* [TODO]: Justification, example
	* New features introduced with the bug fix should be removed: tricky tricky
		* [TODO]: Justification, example
	* Similar or same functional changes over multiple hunks/diffs: __do not__ remove
		* [TODO]: Complete the statement, justification, example 
3. Functions added in fixed version that may or __may not__ be removed
	* Refactoring: if newly added helper function merely contains code refactored from another 	method, and the refactored code is not reused by any other method, remove the change. __Do 	not__ remove the addition of helper function if it is a refactoring and the function 	is used somewhere else.
		* [TODO]: Justification, and example of removable vs non-removable
	* Bug fix function: __do not__ remove (remind to delete new features again)
		* [TODO]: Complete the statement, add justification and example

## Guidelines of Ideal Minimized Patches
##### Overall, a minimized patch is expected to have the following properties:
1. Excludes all space, comment, new lines, and tab changes
2. Excludes all sementically equivalent changes
3. Excludes changes to import statements properly
4. Excludes not reused refactorings properly
5. Includes relevant changes that are being used by the part of the code which triggers the bug
	* [TODO]: example, and add it as a rule
6. Includes all similar (or same) fixes that is introduced over multiple parts of the program, even though there might only be one part of the fix that triggers the bug
		
	