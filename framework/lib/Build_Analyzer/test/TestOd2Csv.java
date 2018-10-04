import static org.junit.Assert.assertTrue;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.UnsupportedEncodingException;

import org.apache.commons.io.FileUtils;
import org.junit.Test;

public class TestOd2Csv {

	@Test
	public void testMain() throws UnsupportedEncodingException, FileNotFoundException, IOException {
		Driver.main(new String[] {"test/projects/od2csv","test/actual_output/od2csv","build.xml"});
	}

  @Test
	public void testTarget() throws IOException {
		File expected = new File("test/expected_output/od2csv/info");
		File actual = new File("test/actual_output/od2csv/info");
		boolean isTwoEqual = FileUtils.contentEquals(expected, actual);
		assertTrue(isTwoEqual);
	}

	@Test
	public void testIncludes() throws IOException {
		File expected = new File("test/expected_output/od2csv/includes");
		File actual = new File("test/actual_output/od2csv/includes");
		boolean isTwoEqual = FileUtils.contentEquals(expected, actual);
		assertTrue(isTwoEqual);
	}

	@Test
	public void testExcludes() throws IOException {
		File expected = new File("test/expected_output/od2csv/excludes");
		File actual = new File("test/actual_output/od2csv/excludes");
		boolean isTwoEqual = FileUtils.contentEquals(expected, actual);
		assertTrue(isTwoEqual);
	}

	@Test
	public void testTestList() throws IOException {
		File expected = new File("test/expected_output/od2csv/developer-included-tests");
		File actual = new File("test/actual_output/od2csv/developer-included-tests");
		boolean isTwoEqual = FileUtils.contentEquals(expected, actual);
		assertTrue(isTwoEqual);
	}
}
