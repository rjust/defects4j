package foo.bar;

import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class FailingTests {

  @Test
  public void test0() {}
// Defects4J: flaky method
//   @Test
//   public void test0() {
//     assertTrue(false);
//   }

  @Test
  public void test1() {}
// Defects4J: flaky method
//   @Test
//   public void test1() {
//     assertTrue(false);
//   }

  @Test
  public void test2() {}
// Defects4J: flaky method
//   @Test
//   public void test2() {
//     assertTrue(false);
//   }
}
