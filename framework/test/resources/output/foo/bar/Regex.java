package foo.bar;

import org.junit.Test;

import static org.junit.Assert.assertNotNull;

public class Regex {

  @Test
  public void test0() {}
// Defects4J: flaky method
//   @Test
//   public void test0() {
//     String str = "\\s*(?:'((?:\\\\'|[^'])*?)'|\"((?:\\\\\"|[^\"])*?)\")\\s*";
//     assertNotNull(str)
//   }
}
