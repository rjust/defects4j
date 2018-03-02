package util;

import java.nio.file.Path;
import java.nio.file.Paths;

public class FileUtility {
	
	/**
	 * "absolute" is expected to be the base directory in absolute path
	 * "path" can be relative or aboslute
	 * 
	 * @param String absolute
	 * @param String path
	 * @return
	 * A relative path version of "path" in relation to "absolute" 
	 */
	public static String absoluteToRelative(String absolute, String path) {
		
		/**
		 * Since MAC don't have Drive likes Windows
		 * getRoot or isAsolute can't distinguish relative path from absolute
		 * 
		 */
		
		if(!path.contains(absolute))
			if(!absolute.contains(path))
				return path;
		
		//Initialize "path" and "absolute" as Path object to take advantage of the library
		Path original_path = Paths.get(path);
		Path absolute_path = Paths.get(absolute);
		
		/**
		 * Check if original_path is a in absolute path form 
		 * and has the same type/root as absolute_path
		 */
		if(!original_path.isAbsolute())
			return path;
		
		//Find the relative path from absolute_path to original_path 
		String relative_path = absolute_path.relativize(original_path).toString();
		
		//Final null checkpoint
		if(relative_path!=null) {
			return relative_path;
		}
		
		//Return the original "path" if there isn't a solution
		return path;
			
	}
	
	
    
}
