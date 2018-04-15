package util;

import org.apache.tools.ant.DirectoryScanner;

/**
 * This is a helper class that allows user to input a directory and wildcards,
 * outputting all file names that match.
 *
 */
public class WildCardResolver {
	private static DirectoryScanner ds;

	public static String[] resolveWildCard(String[] includes, String[] excludes, String baseDir) {
		ds = new DirectoryScanner();
		ds.setIncludes(includes);
		ds.setExcludes(excludes);
		ds.setBasedir(baseDir);
		ds.setCaseSensitive(true);
		// Catch the exception if the directory cannot be found
		try {
			ds.scan();
		}catch(IllegalStateException e){
			Debugger.log("Illegal State Exception found resolving wild cards, basedir does not exist.\n"
					+ "A list of test file wildcard patterns are written to includes/excludes file.");
		}
		return ds.getIncludedFiles();
	}

//	public static String[] getExcludedFiles
}
