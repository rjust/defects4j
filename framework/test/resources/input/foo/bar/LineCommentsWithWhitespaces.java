package foo.bar;

import org.junit.Test;

import static org.junit.Assert.assertEquals;

public class LineCommentsWithWhitespaces {

  @Test
  public void test0() {
    String str = "_hello_";
    assertEquals(" title=\" title=\"\" alt=\"\"", str); // (Primitive) Original Value:  title=" title="" alt="" | Regression Value:  title=" title=&quot;" alt=""
  }
}
