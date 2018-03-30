
import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.nio.file.Paths;

import util.FileWriter;
/**
 * Determines which output is needed for Defects4J, and write results to
 * files(file names can be customized here).
*/
public class Driver {

	public static void main(String[] args) throws UnsupportedEncodingException, FileNotFoundException, IOException {
		String pathToProject = "";
		String pathToOutput = "";
		File buildFile;

		if(args.length == 3) {
			pathToProject = args[0];
			pathToOutput = args[1];
			buildFile = new File(pathToProject+Paths.get("/")+args[2]);

			Analyzer analyzer = new Analyzer(buildFile);
			FileWriter.write(pathToOutput+Paths.get("/")+"targets", analyzer.getCompileTarget().getName()+'\n'+analyzer.getCompileTestTarget());
			FileWriter.write(pathToOutput+Paths.get("/")+"includes", analyzer.getIncludes());
			FileWriter.write(pathToOutput+Paths.get("/")+"excludes", analyzer.getExcludes());
			FileWriter.write(pathToOutput+Paths.get("/")+"developer-included-tests", analyzer.getTests());
		}

		else {
			System.out.println("Check your arguments:\n arg[0] = project directory\n arg[1] = output directory\n arg[3] = build file name");
		}



	}

}
