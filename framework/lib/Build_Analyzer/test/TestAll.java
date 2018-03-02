import static org.junit.Assert.assertTrue;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.UnsupportedEncodingException;

import org.apache.commons.io.FileUtils;
import org.junit.Test;

public class TestAll {
	
	@Test
	public void testMain() throws UnsupportedEncodingException, FileNotFoundException, IOException {
		
		Driver.main(new String[] {"test/projects/commons-lang","test/actual_output","maven-build.xml"});
	}
	
	@Test
	public void testTarget() throws IOException {
		File expected = new File("test/expected_output/targets.txt");
		File actual = new File("test/actual_output/targets.txt");
		boolean isTwoEqual = FileUtils.contentEquals(expected, actual);
		assertTrue(isTwoEqual);
	}
	
	@Test
	public void testIncludes() throws IOException {
		File expected = new File("test/expected_output/includes.txt");
		File actual = new File("test/actual_output/includes.txt");
		boolean isTwoEqual = FileUtils.contentEquals(expected, actual);
		assertTrue(isTwoEqual);
	}
	
	@Test
	public void testExcludes() throws IOException {
		File expected = new File("test/expected_output/excludes.txt");
		File actual = new File("test/actual_output/excludes.txt");
		boolean isTwoEqual = FileUtils.contentEquals(expected, actual);
		assertTrue(isTwoEqual);
	}
	
	@Test
	public void testTestList() throws IOException {
		File expected = new File("test/expected_output/developer-included-tests.txt");
		File actual = new File("test/actual_output/developer-included-tests.txt");
		boolean isTwoEqual = FileUtils.contentEquals(expected, actual);
		assertTrue(isTwoEqual);
	}
	
}
