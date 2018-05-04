# Patch Minimization Guide

This document includes:

1. Guidelines of ideal minimized patches
2. Instructions to perform patch minimization, along with justifications and code examples 
3. Things to avoid minimizing
4. Comprehensive examples of non-minimized vs. minimized patches

## Guidelines of Ideal Minimized Patches [TODO: link]
##### Overall, a minimized patch is expected to have the following properties:
1. [Excludes all refactoring changes](#Code-of-Refctorings-Should-be-Removed)
2. Excludes changes to import statements properly
3. Excludes changes to override statements properly
4. Excludes all the removal of unused code(unused variables, functions, etc.)
5. Exclude changes of adding new features properly
6. Includes all relevant changes that are being used by the part of the code which triggers the bug
7. Includes all similar (or same) fixes that is introduced over multiple parts of the program, even though there might only be one part of the fix that triggers the bug

## Instructions to Using the Framework [TODO: move to bug-mining readme]

### Meld
By default, running `./minimize-patch.pl -p <project> -w <working-directory> -b <bug.id>` will automatically open up meld.  Meld is a user-friendly editor to visualize the changes introduced in the patch.  Visit [Meld](http://meldmerge.org/help/) for further instructions to download.

### Other Editors
Feel free to use any other editors.  Reference [The Secret of Editing Hunks](http://joaquin.windmuller.ca/2011/11/16/selectively-select-changes-to-commit-with-git-or-imma-edit-your-hunk) at the bottom of the page to mannually edit patches.  REMINDER: some editors, such as Atom, will automatically remove the spaces at the end of the file, causing the patch file to be corrupted.

### Restoring Original Patch
Delete corresponding patch under `patch` directory, and re-run `./initialize-revision.pl -p <project> -w <working-directory> -b <bug.id>`

## Understanding the Bug and Narrowing Down the Scope

Keep in mind that each patch is a reverse patch -- applying patch to fixed version will re-introduce the bug.

Read corresponding stack trace under `trigger_tests` directory to get a rough idea of how to re-introduce the bug. Determine the failed test (in `package.className::methodName`format). Delete irrelevant changes(diffs) -- any diff that do not appear in the stack trace

Commit messages, comments, and sometimes the messages included in exception can also be helpful to gain more insight on the bugs.
## Common Types of Bug Fix and Proposed Rules to Disambiguate Results
### 1. Code of Refctorings Should be Removed

Code refactoring is the process of restructuring existing code without changing its external behavior. Since it does not affect the behavior of the code, refactoring is not part of of bug fixes and can be removed from bug-fix patch in order to minimize the patch. code refactoring may consist one or more of the following:

1. __White/spaces/tabs/new lines__
	
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
	
2. __Comments__
     Comments could be considered as part of the bug fix: a developer may 	want to associate a comment with a bug fix and therefore include it in the pure bug-fixing patch; a researcher may want to ignore comments when reasoning about the complexity of a bug-fixing patch. Since here, we are interested in minimizing the code 	to create a minimal bug/ minimal fix, we can remove all the comments and documentation 	elements from the code.

3. __Sementically equivalent changes__
    If the only changes are in the style of programming, then those changes will be semantically equivalent. These changes will have no effect on the bug as they produce the same output before and after change. These changes should be removed from the bug-fix patch.  
    * Example: `byte b[]` and `byte[] b` are the same
        ```diff
        -      public int read(byte b[], final int off, final int len) throws IOException
        +      public int read(byte[] b, final int off, final int len) throws IOException
        ```

4. __Code extracted into a local variable.__
    Code extracted into a local variable should be removed from the minimized patch __if and only if__ it does not generate any new compiler warnings. 
	    
    * Example: The two if statements are sementically equivalent. Since the change does not affect functionalities at all, the declaration and use of the variable `includeProperty` can be removed from the patch. 
	    * Non-minimized:
		```diff
		-      if (getInclude() != null && key.equalsIgnoreCase(getInclude())) 
		-          return true;
		+      String includeProperty = getInclude();
		+      if (includeProperty != null && key.equalsIgnoreCase(includeProperty)) 
		+          return false;
		```
        * Minimized:
    
        ```diff
		       if (includeProperty != null && key.equalsIgnoreCase(includeProperty))
		-          return true; 
		+          return false;
		```

          
    * Example: The example below shows two variables, `key` and `contains` which are newly introduced variables. The bug fix code is `[2]`, which stores the result of the function `containsKey(key)`. Since the `contains` is used for the bug fix, this change should be kept in the patch. However, we can remove the delaration and initialization of `key` `[1]` as we can discard the refactoring and replace the varialbe with the function call in the `put()` `[3]`. If we try to remove `[2]` the compiler will generate a warning `WARNING: Value of local variable is not used`.  
        
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
5. __Code extracted into a Function.__
    If a part of code is extracted into a new helper method, without any change, this move should be removed from the bug-fix patch. Helper functions can be considered as refactoring and can be removed from bug-fix patches.This is similar to case [4]. Since we are moving a peice of code __without any changes__ into a function, the inline code will now be replaced with a function call. This will not affect the outcome of the program and will not affect the bug. 
	
    * Example: Collection - 19    [Todo : explanation]
        
        * Non-Minimized
        ```diff
            public class MultiKey implements Serializable {
        -   calculateHashCode(keys);
        +   int total = 0;
        +   for (int i = 0; i < keys.length; i++) {
        +   if (keys[i] != null) {
        +       total ^= keys[i].hashCode();
        +       }
        +   }
        +   hashCode = total;
        
        -   private void calculateHashCode(Object[] keys)
        -   {
        -       int total = 0;
        -       for (int i = 0; i < keys.length; i++) {
        -           if (keys[i] != null) {
        -               total ^= keys[i].hashCode();
        -           }
        -       }
        -       hashCode = total;
        -   }  
        
        -   private Object readResolve() {
        -	calculateHashCode(keys);
        -		return this;
        -	}  
        ```
        * Minimized
        ```diff
            public class MultiKey implements Serializable {
              calculateHashCode(keys);
              ...
            }
            private void calculateHashCode(Object[] keys)
              ...
            }  
        
        -   private Object readResolve() {
        -	calculateHashCode(keys);
        -		return this;
        -	}  
        ```
     
    
### 2. Changes Made to Import Statements Should be Removed

Although removing changes involving import statements might create new warnings of “unused imports”, import statements would not communicate anything about the bug or the bug fix since it would only 	be necessary to support functions. It is also worth noting that these import statements could be completely removed by using the fully qualified function names. 
			

### 3. Changes Made to @override Statements Can be Removed Under Some Circumstances
In Java, `@override` notation forces compiler to double-check if such method is overriding the method in superclass(often used to check typos in method signature and return type).  Therefore, merely adding @override to existing method is not a functional change. If @override notation comes along with a new or modified method in fixed version, we can keep the addition so it is more obvious to researchers that a method is overriden.

1. if `@override` is added to a pre-existing method and there are no changes made to that specific method in fixed version, remove the change from patch. 

    * Example: the change of override notation in this case should be removed.
    Non-minimized:
        ```diff
        -      @override
               public String toString(){
                 ...
               }
        ```
2. if `@override` is added to a new method and or to an existing method with code changes, __do not__ remove the change from patch.

    * Example: the change of override notation in this case should be retained since @override is added(from buggy->fix) with the addition of the entire method.
        ```diff
        -      @override
        -      public String toString(){
        -          return this.name;
        -      }
        ```
        
      
      
     

### 4. Changes to Remove Unused Code Should be Removed         
        
Removing unused piece of code, like declaration of unused variable, unused import statements, unused functions or evaluated expressions whose result is never used, can be removed from the patch.
* Example: In the following example, `count(totalRead)` is removed in the fixed version as it is an expression that is evaluated but the return value(temp) is never used in the bug fix. In this case, we also made sure that `numToRead` in the bug-fix statement is not altered by `count(totalRead)`. Therefore, the change can be removed form the patch. 

    * Non-Minimized:
        ```diff
		     totalRead = is.read(buf, offset, numToRead);
        +    int temp = count(totalRead);
         
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
        	
### 5. New Features Introduced With the Bug Fix Should be Removed: 
New features added along with bug fix code are tricky to identify since they are blended into the bug-fixing code.  Functions/code involving new features and the function calls to the new features should be completely removed to obtain a minimized patch.

1. __New functions__
    * Example: In the following example, a helper function `calculateMatchNumber` is added in order to fix the bug. The `getMatchCount` is a new feature and it is not related to the bug fix at all.  Therefore, we can remove the change regarding getMatchCount.
        * Non-minimized:
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
        * Minimized:
            ```diff
            -      private int calculateMatchNumber(String matchName){...}
                   public int getMatchNumber(String matchName){
            -         return calculateMatchNumber(index); 
            +         return this.matchNumber; 
            ```
2. __Modifier changes__




## Things to Avoid Minimizing
### 1. Similar or same functional changes over multiple hunks/diffs __should not__ be removed:
Although the bug may be triggered by only one part of the changes, retaining the other similar changes is important -- the tests written by the developers might not cover all the cases introduced in the bug fix, but only the case that triggers the bug.  The entire artifact may contain important information to researchers.
* Example: [Collections 6 non-minimized patch](https://github.com/ypzheng/defects4j/blob/merge-bug-mining-into-master/framework/bug-mining/code-example/col.6.nonminimized.patch) contains 6 similar changes over different parts of the program.  Although there is only one hunk that triggers the bug, we should keep all changes.



### 2. Bug fix function: __do not__ remove the changes to bug fix function from the patch
Even though only leaving the statement that calls the bug fixing function in the patch is able to re-introduce the bug. If there are new features, do not forget to remove new features.
* Example: In this case, do not remove the removal of the bug-fixing function as it is an essential part of the bug fix.
	```diff
    -      protected boolean isGameOver(){...}
           public Player getWinner(){
                 ...
    -      if(this.isGameOver()){...}
    ```


## Comprehensive Examples of Non-minimized vs Minimized Patches[TODO]
1. Collections 19 [Non-minimized](https://github.com/ypzheng/defects4j/blob/merge-bug-mining-into-master/framework/bug-mining/code-example/col.19.nonminimized.patch) vs [Minimized](https://github.com/ypzheng/defects4j/blob/merge-bug-mining-into-master/framework/bug-mining/code-example/col.19.minimized.patch)
    * Highlight comment, import statement, refactored helper function, addition and removal of private variables
3. Compress 6
    * Highlight comment, private variables, new features
