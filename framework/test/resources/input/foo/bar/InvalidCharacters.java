package foo.bar;

import org.junit.Test;

import static org.junit.Assert.assertEquals;

public class InvalidCharacters {

  @Test
  public void test0() {
    assertEquals("'" + "" + "' != '" + "#',(-2&)\r%\".#\"-'\f&.+\n3\f)0!%(\"#( -'\n20&!-- +-//\n#$'#3-%)1$(," + "'", "#',(-2&)\r%\".#\"-'\f&.+\n3\f)0!%(\"#( -'\n20&!-- +-//\n#$'#3-%)1$(,");
  }
}
