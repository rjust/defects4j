import static org.junit.Assert.assertTrue;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.UnsupportedEncodingException;

import org.apache.commons.io.FileUtils;
import org.junit.Test;

public class TestCodeC {

	@Test
	public void testMain() throws UnsupportedEncodingException, FileNotFoundException, IOException {

		Driver.main(new String[] {"test/projects/CodeC","test/actual_output/CodeC","build.xml"});
	}
  @Test
	public void testTarget() throws IOException {
		File expected = new File("test/expected_output/CodeC/info");
		File actual = new File("test/actual_output/CodeC/info");
		boolean isTwoEqual = FileUtils.contentEquals(expected, actual);
		assertTrue(isTwoEqual);
	}

	@Test
	public void testIncludes() throws IOException {
		File expected = new File("test/expected_output/CodeC/includes");
		File actual = new File("test/actual_output/CodeC/includes");
		boolean isTwoEqual = FileUtils.contentEquals(expected, actual);
		assertTrue(isTwoEqual);
	}

	@Test
	public void testExcludes() throws IOException {
		File expected = new File("test/expected_output/CodeC/excludes");
		File actual = new File("test/actual_output/CodeC/excludes");
		boolean isTwoEqual = FileUtils.contentEquals(expected, actual);
		assertTrue(isTwoEqual);
	}

	@Test
	public void testTestList() throws IOException {
		File expected = new File("test/expected_output/CodeC/developer-included-tests");
		File actual = new File("test/actual_output/CodeC/developer-included-tests");
		boolean isTwoEqual = FileUtils.contentEquals(expected, actual);
		assertTrue(isTwoEqual);
	}


}
