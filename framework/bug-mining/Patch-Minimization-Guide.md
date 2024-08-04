# Patch Minimization Guide

This document includes:

1. [Properties of ideal minimized patches](#properties-of-ideal-minimized-patches)
2. [Rules for performing patch minimization](#rules-for-performing-patch-minimization)
3. [Situations that do not require minimization](#do-not-remove-changes-in-the-following-situations)
4. [Examples of non-minimized vs. minimized patches](#examples-of-non-minimized-vs-minimized-patches)

Note: The top-level [Bug-Mining README](https://github.com/rjust/defects4j/blob/master/framework/bug-mining/README.md) outlines the entire bug-mining process and describes when and how patch minimization should be performed.

## Properties of ideal minimized patches

#### Overall, a minimized patch is expected to have the following properties:
1. [Excludes all refactoring changes](#1-refactoring-should-be-removed)
2. [Excludes compiler directives and annotations properly](#2-compiler-directives-and-annotations)
3. [Excludes new features introduced with bug fixes](#3-new-features-introduced-with-the-bug-fix-should-be-removed)
4. [Includes all relevant changes to bug-triggering code](#1-do-not-remove-new-features-added-to-fix-the-bug)
5. [Includes all similar (or same) fixes that are introduced over multiple parts of the program](#2-similar-or-same-functional-changes-over-multiple-diffs-should-not-be-removed)
6. [Include all changes that determine the reason for test failure](#3-changes-that-alter-the-reasons-for-test-failure-should-be-retained)

## Understanding the bug and narrowing the scope

To minimize a patch, edit a file in `framework/projects/PROJECTNAME/patches/` to be smaller.

Keep in mind that each patch in `framework/projects/PROJECTNAME/patches/` is a reverse patch -- we apply this patch to the fixed version of the program in order to reintroduce the bug.  To see the forward patch (for code only, not tests), check out both the buggy and fixed versions of the program and diff them.

Proper minimization requires an understanding of *what* the fault in the code means, and how it affects the system. 
Three key pieces of information should guide your minimization:
* The bug report: The `active-bugs.csv` includes a link to the bug report (or, in some cases, a pull request). 
* The commit message: The `active-bugs.csv` includes the hash of the commit that fixes the bug. The commit message often explains what was changed and *why*. 
* The trigger tests: Each fault has a set of trigger tests -- tests that fail on the buggy version and pass on the fixed version. The trigger test file lists
the failing tests and, for each, includes the stack trace of the failing test case.

These three pieces of information should hep you decide which code changes are relevant to the bug itself, and which code changes are irrelevant to the faulty behavior.

For example, consider bug Closure-174:
 * [Bug Report](https://storage.googleapis.com/google-code-archive/v2/code.google.com/closure-compiler/issues/issue-1103.json)
 * [Commit Message](https://github.com/google/closure-compiler/commit/d2b3ca66b6088c1c08437c120ae215d91d313b7c)
 * [Trigger Tests](https://github.com/rjust/defects4j/blob/master/framework/projects/Closure/trigger_tests/174)

The bug report indicates that the compiler will crash on `goog.scope locals`. The commit message specifically notes that the change ensured that `ScopedAliases` do not crash then where is a 
`dangling var` reference. The three trigger tests then provide examples of situations where the bug causes a program failure in the faulty version -- where the local variables are in the `goog.scope` but
are not aliases. 

This information suggests that code changes unrelated to aliases and scoping are likely irrelevant to the fault. Many of the changes in this patch *are* relevant, but a logger call was removed 
from the buggy version (thus, a line added by the Defects4J patch) that is unrelated to the behavior. Instead, this removal was an unrelated refactoring, and can be removed from the patch.

## Rules for performing patch minimization

### 1. Refactoring should be removed   

Code refactoring is the process of restructuring existing code without changing its visible behavior. It is often performed to improve program *quality*, but should not result in differing program output.
Since refactoring does not affect the behavior of the code, it is not considered part of a bug fix, and the changes introduced during refactoring should be removed from the Defects4J patch. 

Code refactoring may consist of one or more of the following:

1. __White space, tabs, and new lines__  

	* Example 1: In the following example, an `if` block is added to the code to fix the bug. An existing expression `result = a/b;` is placed inside this block. Because the indentation of this line was changed, the non-minimized patch indicates that the line was deleted and an indented version was added to fix the bug. This changed line -- changing indentation -- is a refactoring, and is not required to fix the bug. Therefore, we only keep the addition of the "if" statement.
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

    * Example 2: Collections-71 contains several tab changes (refactorings) that result in an unnecessarily large patch. See [Collections-71 non-minimized](https://github.com/rjust/defects4j/blob/master/framework/bug-mining/code-example/col.71.preminimized.patch) vs. [Collections-71 minimized](https://github.com/rjust/defects4j/blob/master/framework/bug-mining/code-example/col.71.minimized.patch)

2. __Comments__  
     Comments could be considered as part of the bug fix: a developer may want to associate a comment with a bug fix and therefore include it in the pure bug-fixing patch. However, a researcher may want to ignore comments when reasoning about or analyzing a bug-fixing patch. Therefore, we remove all changes to comments or documentation from the patch. This information can be seen by directly examining the commits, as offered in the `active-bugs.csv`.

3. __Sementically-equivalent changes__  
    Changes that do not alter the visible program behavor -- those that are semantically equivalent across program versions -- can be removed. These changes will have no effect on the bug as they produce the same output before and after the change.
    * Example 1: `byte b[]` and `byte[] b` are the same
        ```diff
        -      public int read(byte b[], final int off, final int len) throws IOException
        +      public int read(byte[] b, final int off, final int len) throws IOException
        ```

    * Example 2: In this example, the bug fix changes the `while` loop to a `for` loop.  The changes have no effect on the functionality.  Therefore, we can remove the change from the patch.
        ```diff
        -    for(int i=0;i<100;i++)
             {
                //Loop_body;
             }
        +    int i = 0;
        +    while(i<100)
             {
                //Loop_body;
        +       i++;
             }
        ```

4. __Code extracted into a local variable__  
    Code extracted into a local variable should be removed from the minimized patch __if and only if__ the change does not generate any new compiler warnings.

    * Example 1: The two `if` statements are sementically equivalent. Since the change does not affect functionality at all, the declaration and use of the variable `includeProperty` can be removed from the patch.
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


    * Example 2: The example below shows two variables, `key` and `contains`, that are newly introduced variables. The bug fix code is in line [2], which stores the result of the function `containsKey(key)`. Since the `contains` is used for the bug fix, this change should be kept in the patch. However, we can remove the delaration and initialization of `key` in line [1] as we can discard the refactoring operation and replace the variable `key` with the function call in the `put()` in line [3]. Note that we do not remove line [2] from the patch because the compiler will generate a warning `WARNING: Value of local variable is not used` if we try to remove line [2].  

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

5. __Code extracted into a function__  
    If a part of the code is extracted into a new helper method without any functionality changes, this operation could be considered as refactoring and can be removed from the patch. This is similar to case [4] explained above. Since we are moving a piece of code __without any changes__ into a function, the inline code will now be replaced with a function call to the helper method. This will not affect the outcome of the program and will not affect the bug.

    * Example: Below is an example from Collection-19. In this example, a part of the code that computes the hash code for a key has been moved into a seperate helper function. Since there is no change with respect to the lines of code that actually calculate the hash code, this can be seen as a refactoring operation. However, this newly created function is also called by the bug-fix method `readResolve`, therefore, all changes to `readResolve` should remain in the patch.  

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

6. __Cleaning up and removing dead code__  
        Removal of unused pieces of code -- such as declarations of unused variables, unused import statements, unused functions, or results of expressions that are never used -- should be removed from the patch.

    * Example: In the following example, `count(totalRead)` is removed in the fixed version because it is an expression that is evaluated but is never being used in the bug fix. Also, since `numToRead` in the bug-fix statement is not altered by `count(totalRead)`, `count(totalRead)` does not affect the bug fix at all.  Therefore, this change can be removed from the patch.

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

7. __Breaking down conjunctions into nested if blocks__  
    Another common refactoring observed was a conjunction broken down into nested if statements. This is done to access cases where one of the conditions evaluate to true and the other to false. This operation can sometimes be seen as refactoring. Keep in mind that removing these kinds of changes may require several iterations of testing(between removing/altering the patch and restoring the original patch). If removing/altering this change neither affects the bug nor creates any new compiler errors or warnings, remove the change from the patch.

    * Example: The example below demonstrates a case like this. Two conditons(a and b) were used with conjunction. The bug fix was one of the cases where the condition a is true and b is false. To access this case, the conjunction has to be broken into nested if statements.  However, we can discard the changes regarding `if(a && b)` and `if(a) if(b)` as they are actually equivalent.

        * Non-Minimized:
            ```diff
            +      if(a && b)
                       //statement_block1
            -      if(a)
            -      {
            -           if(b)
            -           {
                            //statement_block1
            -           }
            -           else
            -           {
            -               //bug_fix
            -           }
            -      }
            ```
        * Minimized:
            ```diff
                  if(a)
                  {
                       if(b)
                       {
                            //statement_block1
                       }
            -          else
            -          {
            -              //bug_fix
            -          }
                  }
            ```



### 2. Compiler directives and annotations

1. __Changes made to import statements that are not relevant to the bug fix should be removed__
    Although removing changes involving import statements might create new warnings of `unused import statements`, import statements would not communicate anything about the bug or the bug fix since they would only be necessary to support functions. It is also worth noting that these import statements could be completely removed by using the fully qualified function names.

2. __Changes made to @override statements can be removed under some circumstances__  
    In Java, the `@override` annotation forces the compiler to double-check if the annotated method is overriding a method in the superclass (this operation is often used to check typos in method signatures and return types).  Therefore, merely adding @override statements to existing methods is not a functional change. However, if the `@override` annotation comes along with a new or modified method in fixed version, we can keep the addition.

    1. If `@override` is added to a pre-existing method and there are no changes made to that specific method in fixed version, remove the change from patch.

        * Example: The change of override annotation in this case should be removed.
        Non-minimized:
            ```diff
            -      @override
                   public String toString(){
                     ...
                   }
            ```
    2. If `@override` is added to a new method and or to an existing method with code changes, __do not__ remove the change from patch.

        * Example: The change of override annotation in this case should be retained since @override is added (from buggy->fix) with the addition of the entire method.
            ```diff
            -      @override
            -      public String toString(){
            -          return this.name;
            -      }
            ```
3. __Changes made to @suppressWarnings should be removed__  
    In Java, the `@suppressWarnings` annotation allows programmers to disable compilation warnings in certain part of the code.  Similar to `@override` annotations, `@suppressWarnings` only mutes the warnings and has no affect on the bug fix.  Therefore, we can remove all changes involving `@suppressWarnings`.

4. __Changes to variable modifiers should be tested and removed__  
    Modifiers enforce restrictions on the contents of a variable. These restrictions may or may not be relevant to the bug fix. If removing these changes from the patch does not cause compilation errors or affect the bug, then the change should be removed.

    * Example: The `final` keyword is used in several contexts to define an entity that can only be assigned once.  It is also considered a good programming practice to make function parameters final. Below is an example from Compress-48. The bug fix in this patch is in the `throw` statement. The modifier `final` in `parseOctal` does not affect the bug, therefore the change involving the `final` modifier should be removed.

        * Non-Minimized:
            ```diff
            +     public static long parseOctal(final byte[] buffer, final int offset, final int length) {
            -     public static long parseOctal(byte[] buffer, int offset, int length) {
                     int     end = offset + length;
                     int     start = offset;

            -        if (length < 2){
            -              throw new IllegalArgumentException("Length "+length+" must be at least 2");
            -         }
            ```
        * Minimized:
            ```diff
                  public static long parseOctal(final byte[] buffer, final int offset, final int length) {
                     int     end = offset + length;
                     int     start = offset;

            -        if (length < 2){
            -               throw new IllegalArgumentException("Length "+length+" must be at least 2");
            -        }

            ```

### 3. New features introduced with the bug fix should be removed:  

New features added along with bug fix code, that are not part of a bug fix, are tricky to identify since they are usually blended into the bug-fixing code. Functions or code involving new features and the function calls to the new features should be completely removed to obtain a minimized patch.

1. __New functions__
    * Example: In the following example, a helper function `calculateMatchNumber` is added in order to fix the bug. The `getMatchCount` is a new feature and is not related to the bug fix at all.  Therefore, we can remove the change regarding `getMatchCount`.
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



## Do not remove changes in the following situations

### 1. Do not remove new features added to fix the bug

Some bug-fix patches will require new features to be included. If a new feature is added to fix the bug, the entire function and the call should be kept in the patch. Although removing the function definition and keeping the call will also reintroduce the bug, __do not__ remove the function definition because it explains the bug fix.

* Example: In this case, do not remove the change in the bug-fixing function as it is an essential part of the bug fix.
    ```diff
    -      protected boolean isGameOver(){...}
           public Player getWinner(){
                 ...
    -      if(this.isGameOver()){...}
    ```

* Example: In the patch shown below, the bug fix code is just the `if` block. Despite that, we cannot remove any other statements from this patch. The while loop contains only the `if` statement, so it cannot be removed. The two new local variables introduced in this function are both being used for the bug fix, so their declarations cannot be removed. The function `clear()` has no other statements other than the two variable declarations and the `while` loop. Hence, removing the function would mean creating an empty function in the buggy version, which would not make any sense. Since the `@Override` is associated with the `clear()` function, even that cannot be removed.
    ```diff
             abstract class AbstractPatriciaTrie<K, V> extends AbstractBitwiseTrie<K, V> {
                    ...
             }
    -        @Override
    -        public void clear() {
    -            Iterator<Map.Entry<K, V>> it = AbstractPatriciaTrie.this.entrySet().iterator();
    -            Set<K> currentKeys = keySet();
    -            while (it.hasNext()) {
    -                if (currentKeys.contains(it.next().getKey())) {
    -                    it.remove();
    -                }
    -            }
    -        }
    ```

### 2. Similar or identical functional changes over multiple diffs should not be removed  
Although the bug may be triggered by only one part of the changes, retaining the other similar changes is important -- the tests written by the developers might not cover all the cases introduced in the bug fix, but only covers the case that triggers the bug.  The entire artifact may contain important information to researchers.
* Example: [Collections 6 non-minimized patch](https://github.com/rjust/defects4j/blob/master/framework/bug-mining/code-example/col.6.nonminimized.patch) contains 6 similar changes over different parts of the program.  Although there is only one hunk that triggers the bug, we should keep all changes.

### 3. Changes that alter the reasons for test failure should be retained

After performing patch minimization, the minimized patch should still yield the same trigger tests -- the same tests should pass and fail for both minimized and the original patch.  To verify this fact, run from `framework/test/`:
```./test_verify_bugs.sh -p PROJECTNAME -bBUGNUMBER```

However, in some cases, code changes that appear to be refactoring could still alter the reason for a test failure. After removing that code change, the same tests may fail, but a different exception or error message may be offered.

Consider Closure-140. The following lines were removed when fixing the bug:
```diff
+    for (JSModule m : getModuleGraph().getTransitiveDepsDeepestFirst(module)) {
+      inputs = m.getInputs();
+      if (inputs.size() > 0) {
+        return inputs.get(0).getAstRoot(this);
+      }
+    }
```

These lines are not immediately apparent as part of the bug fix (other functionality is added that clearly relates to the bug). Removal of these lines will still result in the same
trigger tests -- the same tests still pass and fail. However, removing these lines does result in different *reasons* for test failure -- differing assertion results.  
In such cases, the code changes should be retained in the minimized patch to preserve the proper trigger test behavior.

## Examples of non-minimized vs minimized patches

1. Collections-19 [Non-minimized](https://github.com/rjust/defects4j/blob/master/framework/bug-mining/code-example/col.19.nonminimized.patch) vs. [Minimized](https://github.com/rjust/defects4j/blob/master/framework/bug-mining/code-example/col.19.minimized.patch)
    * Steps and rules used to perform patch minimization:
        1. Remove changes to comments in line [42-45](https://github.com/rjust/defects4j/blob/master/framework/bug-mining/code-example/col.19.nonminimized.patch#L42), and line [57-62](https://github.com/rjust/defects4j/blob/master/framework/bug-mining/code-example/col.19.nonminimized.patch#L57) (Refactoring).
        2. Remove changes to import statements in [line 9 and 10](https://github.com/rjust/defects4j/blob/a881251f0305ed9e1cd26ac454b2b90c27e533ba/framework/bug-mining/code-example/col.19.nonminimized.patch#L9)  (Compiler Directives).
        3. Remove changes to modifiers in line [18 and 19](https://github.com/rjust/defects4j/blob/a881251f0305ed9e1cd26ac454b2b90c27e533ba/framework/bug-mining/code-example/col.19.nonminimized.patch#L18) (Compiler Directives).
        4. The actual bug-fix is calling the private method `calculateHashCode` in [private object readResolve](https://github.com/rjust/defects4j/blob/a881251f0305ed9e1cd26ac454b2b90c27e533ba/framework/bug-mining/code-example/col.19.nonminimized.patch#L63). Although `calculateHashCode` seems like a newly added helper function, it actually is a refactoring operation from some method in [line 28 in the patch](https://github.com/rjust/defects4j/blob/a881251f0305ed9e1cd26ac454b2b90c27e533ba/framework/bug-mining/code-example/col.19.nonminimized.patch#L28).  Therefore, we can discard the changes regarding the refactoring, leaving only the change to bug fix method which contains function call to `calculateHashCode` that actually reintroduces the bug (Refactoring).


2. Compress-6 [Non-minimized](https://github.com/rjust/defects4j/blob/master/framework/bug-mining/code-example/comp.6.nonminimized.patch) vs. [Minimized](https://github.com/rjust/defects4j/blob/master/framework/bug-mining/code-example/comp.6.minimized.patch)
    * Steps and rules used to perform patch minimization:
        1. Remove changes to comments in line 9-12, 14-17, 25-31, and 38-39(Refactoring).
        2. Read stack trace under `trigger_tests` directory and determine bug-triggering code.  In this case, the bug is an assertion failure in deleting archived entries. The bug-fixing change is a new private variable `entryOffset` introduced to the fixed version.  This variable keeps track of where the current entry starts.
        3. Remove irrelevant changes -- hunks that neither modify nor use `entryOffset`.  That only leaves us four hunks:
            1. Nothing to be minimized in this hunk.
                ```diff
                -    private long entryOffset = -1;
                ```
            2. Nothing to be minimized in this hunk.
                ```diff
                     public ArArchiveEntry getNextArEntry() throws     IOException {
                -      if (currentEntry != null) {
                -         final long entryEnd = entryOffset + currentEntry.getLength();
                -         while (offset < entryEnd) {
                -         int x = read();
                -         if (x == -1) {
                              // hit EOF before previous entry was complete
                              // TODO: throw an exception instead?
                -             return null;
                -           }
                -        }
                -       currentEntry = null;
                -      }
                ```
            3. This part of the patch can be minimized.  Note that the two return statements are sementically the same. After minimization, only line [1] will remain in the patch.
                ```diff
                -      entryOffset = offset;[1]
                -      currentEntry = new ArArchiveEntry(new String(name).trim(),
                -                      Long.parseLong(new String(length)
                -                     .trim()));
                -      return currentEntry;
                +      return new ArArchiveEntry(new String(name).trim(), Long.parseLong(new String(length).trim()));
                +
                ```
            4. This part of the patch can also be minimized. Note that line [1] and line [4] are semantically equivalent. Looking at line [3] and line [5], the only difference is the variable `toRead` vs `len` and these two variables are the same according to line [2].  Therefore, we can remove these changes.
                ```diff
                -    public int read(byte[] b, final int off, final int len) throws IOException {[1]
                -    int toRead = len;[2]
                -    if (currentEntry != null) {
                -       final long entryEnd = entryOffset + currentEntry.getLength();
                -         if (len > 0 && entryEnd > offset) {
                -             toRead = (int) Math.min(len, entryEnd - offset);
                -         } else {
                -             return -1;
                -         }
                -     }
                -    final int ret = this.input.read(b, off, toRead);[3]
                +    public int read(byte[] b, int off, int len) throws IOException {[4]
                +    final int ret = this.input.read(b, off, len);[5]
                     offset += (ret > 0 ? ret : 0);
                     return ret;
                ```
                Minimized:
                ```diff
                        int toRead = len;
                -        if (currentEntry != null) {
                -            final long entryEnd = entryOffset + currentEntry.getLength();
                -            if (len > 0 && entryEnd > offset) {
                -                toRead = (int) Math.min(len, entryEnd - offset);
                -            } else {
                -                return -1;
                -            }
                -        }
                         final int ret = this.input.read(b, off, toRead);
                ```

    * After performing the above steps, the patch will be minimized ([Minimized Compress 6](https://github.com/rjust/defects4j/blob/master/framework/bug-mining/code-example/comp.6.minimized.patch)).
