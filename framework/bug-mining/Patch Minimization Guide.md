# Patch Minimization Guide
This document includes: <br>
(1) instructions to run patch minimization related script <br>
(2) instructions to perform patch minimization <br>
(3) guidelines of ideal minimized patch 

## Instructions to Using the Framework
### Meld
By default, running `./minimize-patch .pl -p <project> -w <branch> -b <bug.id>` will automatically open up meld.  Meld is a user-friendly editor to visualize the changes introduced in the patch.  Visit [Meld](http://meldmerge.org/help/) for further instructions to download.
### Other Editors
Feel free to use any other editors.  Reference [The Secret of Editing Hunks](http://joaquin.windmuller.ca/2011/11/16/selectively-select-changes-to-commit-with-git-or-imma-edit-your-hunk) at the bottom of the page to mannually edit patches.  REMINDER: some editors, such as Atom, will automatically remove the spaces at the end of the file, causing the patch file to be corrupted.
### Restoring Original Patch
Delete corresponding patch under `patch` directory, and re-run `./initialize-revision.pl -p <project> -w <branch> -b <bug.id>`

##Instructions to Perform Patch Minimization
### Understanding the Bug
Read corresponding stack trace under `trigger_tests` directory to get a rough idea of how to re-introduce the bug.  Commit messages, comments, and sometimes the messages included in exception can also be helpful.

### Narrowing Down the Scope


### Common Situations That Require Minimization
1. Syntax related changes that need to be removed
	* **White spaces**
	* **Tabs**
	* **Comments**
	* Example: Collections 71 contains tab changes that caused unnecessarily huge patch. [Collections 71 non-minimized](https://github.com/ypzheng/defects4j/blob/merge-bug-mining-into-master/framework/bug-mining/code-example/col.71.preminimized.patch) vs. [Collections 71 minimized](https://github.com/ypzheng/defects4j/blob/merge-bug-mining-into-master/framework/bug-mining/code-example/col.71.minimized.patch)
	* **Sementically equivalent changes** should be removed
		Example: `byte b[]` and `byte[] b` are the same
		
		```diff
		-      public int read(byte b[], final int off, final int len) throws IOException
		+      public int read(byte[] b, final int off, final int len) throws IOException
		```
		
		Example: The two if statements are sementically equivalent
		
		```diff
		-      if (getInclude() != null && key.equalsIgnoreCase(getInclude())) {
		+      String includeProperty = getInclude();
		+      if (includeProperty != null && key.equalsIgnoreCase(includeProperty)) {
		```
		
2. Code changes that can be removed in most of the cases
	* **Import statements**: if an import statement is added in the fixed version, remove the change.
	* **@Override statements**: if `@override` is added to a pre-existing method and there are no changes made to that specific method in fixed version, remove the change.
		* [TODO]: Example of removable vs none-removable
	* **Unused variables/functions**: removal of unused variables and definition of uncalled functions in fixed version should be removed from the patch.
3. Helper functions
	* **Refactoring**: if newly added helper function merely contains code refactored from another method, and the refactored code is not reused by any other method, remove the change. 
		* [TODO]: Add example<br>
		
	