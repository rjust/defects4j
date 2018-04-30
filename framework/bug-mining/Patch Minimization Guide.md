


# Patch Minimization Guide

This document includes:

1. instructions to run patch minimization related scripts
2. instructions to perform patch minimization, along with justifications and code examples
3. guidelines of ideal minimized patches
4. comprehensive examples of non-minimized vs. minimized patches


## Instructions to Using the Framework

### Meld
By default, running `./minimize-patch .pl -p <project> -w <branch> -b <bug.id>` will automatically open up meld.  Meld is a user-friendly editor to visualize the changes introduced in the patch.  Visit [Meld](http://meldmerge.org/help/) for further instructions to download.

### Other Editors
Feel free to use any other editors.  Reference [The Secret of Editing Hunks](http://joaquin.windmuller.ca/2011/11/16/selectively-select-changes-to-commit-with-git-or-imma-edit-your-hunk) at the bottom of the page to mannually edit patches.  REMINDER: some editors, such as Atom, will automatically remove the spaces at the end of the file, causing the patch file to be corrupted.

### Restoring Original Patch
Delete corresponding patch under `patch` directory, and re-run `./initialize-revision.pl -p <project> -w <branch> -b <bug.id>`

##Instructions to Perform Patch Minimization

### Understanding the Bug and Narrowing Down the Scope

Keep in mind that each patch is a reverse patch(applying patch to fixed version will re-introduce the bug).

Read corresponding stack trace under `trigger_tests` directory to get a rough idea of how to re-introduce the bug. Determine the failed test (in `package.className::methodName`format). Delete irrelevant changes(diffs) -- any diff that do not appear in the stack trace

Commit messages, comments, and sometimes the messages included in exception can also be helpful to gain more insight on the bugs b b.


### Common Types of Bug Fix and Proposed Rules to Disambiguate Results
1. All of the following syntax changes introduced to fixed version should be removed since they do not affect the functionalities:
	* White/spaces/tabs/new lines
	    * Example 1: Some white space fixes are tricky because they involve indentation changes. This could be because a part of code was moved into or out of a branch. In this example, the only change to "result" is the tab.
            * Non-minimized:
                ```diff
                -    if(b!=0)
                -    {
                -         result = a/b;
                -    }
                +    result = a/b;
                ```
            * Minimized:
                ```diff
                -    if(b!=0)
                -    {
                          result = a/b;
                -    }
                ```
	    * Example 2: Collections 71 contains tab changes that caused unnecessarily huge patch. [Collections 71 non-minimized](https://github.com/ypzheng/defects4j/blob/merge-bug-mining-into-master/framework/bug-mining/code-example/col.71.preminimized.patch) vs. [Collections 71 minimized](https://github.com/ypzheng/defects4j/blob/merge-bug-mining-into-master/framework/bug-mining/code-example/col.71.minimized.patch)

	* Comments
		* Justification: Comments could be considered as part of the bug fix: a developer may 		want to associate a comment with a bug fix and therefore include it in the pure bug-		fixing patch; a researcher may want to ignore comments when reasoning about the 		complexity of a bug-fixing patch. Since here, we are interested in minimizing the code 		to create a minimal bug/ minimal fix, we can remove all the comments and documentation 		elements from the code

    * Sementically equivalent changes should be removed
		* Justification: The only changes are in the style of programming or a programmer’s 		preference of writing them in one way as opposed to another.
		* Example: `byte b[]` and `byte[] b` are the same
			```diff
			-      public int read(byte b[], final int off, final int len) throws IOException
			+      public int read(byte[] b, final int off, final int len) throws IOException
			```

2. Import statements: if an import statement is added/deleted in the fixed version, remove 	the change.
	* Justification: Although removing changes involving import statements might create new 		warnings of “unused imports”, import 		statements would not communicate anything about the bug or the bug fix. It would only 		be necessary to support functions. It is also worth noting that these import statements 		could be completely removed by using the fully qualified function names. Hence, in some 		sense the import statements can be considered as a refactoring operation.


3. Code extracted into an intermediate variable:
	* Justification: Code that is extracted into a variable instead of immediate usage can be removed from the minimized patch in some circumstances. Recognizing when to do this may be tricky. It is not to be mistaken with a new variable declared only for the purpose of bug fix. If we move such variables, they would have no purpose in the buggy code. Although the bug will still be produced, a new warning, “Value of Local Variable not used” will be generated for the unused variable.

    * Example 1: The two if statements are sementically equivalent. In fact, this is also an example of refactoring. Since the change does not affect functionalities at all, the diff should be completely removed.

		```diff
		-      if (getInclude() != null && key.equalsIgnoreCase(getInclude()))
		+      String includeProperty = getInclude();
		+      if (includeProperty != null && key.equalsIgnoreCase(includeProperty))
		```

    * Example 2: The example below shows two variables, ```key``` and `contains` which are newly introduced variables. The bug fix code is `[2]`, which uses the function `containsKey(key)`. Since the `contains` variable is used only for the bug fix and it has no other use, this change should be kept in the bug fix patch. However, we can remove the delaration and initialization of `key` `[1]` as we could find another use for the variable in the function `put()` `[3]`.

        * Non-minimized
            ```diff
            -    final K key = entry.getKey(); [1]
            -    final boolean contains = containsKey(key);[2]
            -    put(index, entry.getKey(), entry.getValue());
            -    if (!contains) {
            -         final V old = put(index, key, entry.getValue()); [3]
            +         final V old = put(index, entry.getKey(), entry.getValue()); [4]
            +    if (old == null) {
            ```  

        * Minimized
            ```diff
                 final K key = entry.getKey(); [1]
            -    final boolean contains = containsKey(key);
            -    put(index, entry.getKey(), entry.getValue());
            -    if (!contains) {
                    final V old = put(index, key, entry.getValue()); [3]
            +    if (old == null) {
            ```


4. @override statements: if `@override` is added to a pre-existing method and there are no changes made to that specific method in fixed version, remove the change.  Otherwise, __do 	not__ remove the statement.
	* Justification: In Java, `@override` notation forces compiler to double-check if such method is overriding the method in superclass(often used to check typos in method signature and return type).  Therefore, merely adding @override to existing method is not a functional change. If @override notation comes along with a new or modified method in fixed version, we can keep the addition so it is more obvious to researchers that a method is overriden.
	* Example 1: the change of override notation in this case should be removed.
        ```diff
        -      @override
               public String toString(){
                 ...
               }
        ```

    * Example 2: the change of override notation in this case can be retained since it is added(from buggy->fix) with the addition of the entire method.
        ```diff
        -      @override
        -      public String toString(){
        -          return this.name;
        -      }
        ```
5. Unused variables/functions: removal of unused variables and definition of uncalled functions in fixed version should be removed from the patch.
	* Justification:  Removal of unused variables, expressions and definition of uncalled functions are technically non-functional changes.  
	* Example: In the following example, `count(totalRead)` is removed from the patch as it is an expression that is evaluated but the values is never used. Removing this stament was a refactoring operation and hance it has been removed from the minimized patch.

        * Non-Minimized:
        ```diff
		     totalRead = is.read(buf, offset, numToRead);
        +    count(totalRead);

             if (totalRead == -1) {
        -        if (numToRead > 0) {
        -             throw new IOException("Truncated TAR archive");
        -    }
             hasHitEOF = true;
        ```
        * Minimized
        ```diff
            totalRead = is.read(buf, offset, numToRead);

            if (totalRead == -1) {
        -        if (numToRead > 0) {
        -             throw new IOException("Truncated TAR archive");
        -   }
            hasHitEOF = true;
        ```


6. New features introduced with the bug fix should be removed:
	* Justification: New features added along with bug fix code are tricky to identify.  Functions/code involving new features and the function calls to the new features should be completely removed to obtain a minimized patch.
	* Example: In this case, a helper function "calculateMatchNumber" is added in order to fix the bug. The getMatchCount is a new feature and it is not related to the bug fix at all.  Therefore, we can remove the change regarding getMatchCount.
	    * Non-minimized
            ```diff
            -      private int getMatchCount;

            -      private int calculateMatchNumber(int index){...}    
                     public int getMatchNumber(String matchName){
            -         getMatchCount++;
                        ...
            -         return calculateMatchNumber(index);
            +         return this.matchNumber;
                  }
             ```
        * Minimized
            ```diff
            -      private int calculateMatchNumber(String matchName){...}
                   public int getMatchNumber(String matchName){
            -         return calculateMatchNumber(index);
            +         return this.matchNumber;
            ```

7. Similar or same functional changes over multiple hunks/diffs __should not__ be removed:
	* Justification: Although the bug may be triggered by only one part of the changes, retaining the other similar changes is important -- the tests written by the developers might not cover all the cases introduced in the bug fix, but only the case that triggers the bug.  The entire artifact may contain important information to researchers.
	* Example: [Collections 6 non-minimized patch](https://github.com/ypzheng/defects4j/blob/merge-bug-mining-into-master/framework/bug-mining/code-example/col.6.nonminimized.patch) contains 6 similar changes over different parts of the program.  Although there is only one hunk that triggers the bug, we should keep all changes.

8. Helper Function: If a newly added function merely contains code moved from another method, it can be termed as a helper functions.

	* Justification: Helper functions can be considered as refactoring and can be removed from minimized patches.This is similar to case 3(intermediate variable). Since we are moving a peice of code __without any changes__ into a function, the inline code will now be replaced with a function call. Care should be taken not to remove functions that are related to bug fixes.

	* example of removable vs non-removable

9. Bug fix function: __do not__ remove the removal bug fix function from the patch even though only leaving the statement that calls the bug fixing function in the patch is able to re-introduce the bug. If there are new features, do not forget to remove new features, as described in rule #6.
    * Justification: The definition of the bug-fixing function is the most important part of a bug fix.
	* [TODO]: add more justification and example
	* Example: In this case, do not remove the removal of the bug-fixing function as it is an essential part of the bug fix.
	    ```diff
        -      protected boolean isGameOver(){...}
               public Player getWinner(){
                 ...
        -        if(this.isGameOver()){......}
               }
        ```




## Guidelines of Ideal Minimized Patches
##### Overall, a minimized patch is expected to have the following properties:
1. Excludes all space, comment, new lines, and tab changes
2. Excludes all sementically equivalent changes
3. Excludes changes to import statements properly
4. Excludes not reused refactorings properly
5. Includes all relevant changes that are being used by the part of the code which triggers the bug
6. Includes all similar (or same) fixes that is introduced over multiple parts of the program, even though there might only be one part of the fix that triggers the bug

## Comprehensive Examples of Non-minimized vs Minimized Patches[TODO]
1. Collections 19
2. Compress 6
