import static org.junit.Assert.assertTrue;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.UnsupportedEncodingException;

import org.apache.commons.io.FileUtils;
import org.junit.Test;

public class TestConnectFour {

	@Test
	public void testMain() throws UnsupportedEncodingException, FileNotFoundException, IOException {
		Driver.main(new String[] {"test/projects/connect-four","test/actual_output/connect-four","build.xml"});
	}

	@Test
	public void testTarget() throws IOException {
		File expected = new File("test/expected_output/connect-four/targets");
		File actual = new File("test/actual_output/connect-four/targets");
		boolean isTwoEqual = FileUtils.contentEquals(expected, actual);
		assertTrue(isTwoEqual);
	}

	@Test
	public void testIncludes() throws IOException {
		File expected = new File("test/expected_output/connect-four/includes");
		File actual = new File("test/actual_output/connect-four/includes");
		boolean isTwoEqual = FileUtils.contentEquals(expected, actual);
		assertTrue(isTwoEqual);
	}

	@Test
	public void testExcludes() throws IOException {
		File expected = new File("test/expected_output/connect-four/excludes");
		File actual = new File("test/actual_output/connect-four/excludes");
		boolean isTwoEqual = FileUtils.contentEquals(expected, actual);
		assertTrue(isTwoEqual);
	}

	@Test
	public void testTestList() throws IOException {
		File expected = new File("test/expected_output/connect-four/developer-included-tests");
		File actual = new File("test/actual_output/connect-four/developer-included-tests");
		boolean isTwoEqual = FileUtils.contentEquals(expected, actual);
		assertTrue(isTwoEqual);
	}

}
