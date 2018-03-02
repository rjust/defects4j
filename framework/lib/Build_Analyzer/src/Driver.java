
import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.nio.file.Paths;

import util.FileWriter;

public class Driver {

	public static void main(String[] args) throws UnsupportedEncodingException, FileNotFoundException, IOException {
		String pathToProject = "";
		String pathToOutput = "";
		File buildFile;
		
		if(args.length == 3) {
			pathToProject = args[0];
			pathToOutput = args[1];
			buildFile = new File(pathToProject+"/"+args[2]);
			
			Analyzer analyzer = new Analyzer(buildFile);
			FileWriter.write(pathToOutput+Paths.get("/")+"targets.txt", analyzer.getCompileTarget().getName()+'\n'+analyzer.getCompileTestTarget());
			FileWriter.write(pathToOutput+Paths.get("/")+"includes.txt", analyzer.getIncludes());
			FileWriter.write(pathToOutput+Paths.get("/")+"excludes.txt", analyzer.getExcludes());
			FileWriter.write(pathToOutput+Paths.get("/")+"developer-included-tests.txt", analyzer.getTests());
		}
		
		else {
			System.out.println("check your arguments");
		}
		

		
	}

}
