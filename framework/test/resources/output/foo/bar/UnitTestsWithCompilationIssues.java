package foo.bar;

import org.junit.Test;

public class UnitTestsWithCompilationIssues {

  @Test
  public void test0() {}
// Defects4J: flaky method
//   @Test
//   public void test0() {
//     String str = new String();
//     str = 123456789;
//   }

  @Test
  public void test1() {}
// Defects4J: flaky method
//   @Test
//   public void test1() {
//     assertTrue(123456789 == 123456789)
//   }
}
