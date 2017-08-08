package foo.bar;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class ValidTestClass {

  @Test
  public void test0() {
    String str = new String("123456789");
    assertEquals("123456789", str);
  }

  @Test
  public void test1() {
    assertTrue(123456789 == 123456789);
  }
}
