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
			System.out.println("Illegal State Exception found resolving wild cards, basedir does not exist.\n"
					+ "Instead, a list of wildcards that matches test file pattern is written to build.properties.");
		}
		return ds.getIncludedFiles();
	}
	
//	public static String[] getExcludedFiles
}
