
import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.nio.file.Paths;
import java.util.Scanner;

import util.FileWriter;
import util.WildCardResolver;

public class Driver_2 {

	public static void main(String[] args) throws UnsupportedEncodingException, FileNotFoundException, IOException {
		String pathToProject = "";
		String pathToOutput = "";
		File dir, buildFile;
		Scanner scanner = new Scanner(System.in);
		
		
		System.out.println("Please input a path to the project: ");
		pathToProject = scanner.nextLine();
		System.out.println("Please input a path to write the result: ");
		pathToOutput = scanner.nextLine();
		
		dir = new File(pathToProject);
		if(!dir.isDirectory()) {
			System.out.println("Not a directory");
		} else {
			String[] includes = {"*build**.xml","*Build**.xml"};
			String[] excludes = {};
			String buildFiles[] = WildCardResolver.resolveWildCard(includes, excludes, dir.toString());
			if(buildFiles.length == 1) {
				System.out.println("one found");
				buildFile = new File(dir.getPath() + Paths.get("/") + buildFiles[0]);
			}
			else if(buildFiles.length == 0) {
				System.out.println("No build file found, please manually input your build file name: ");
				int index = pathToProject.lastIndexOf(Paths.get("/").toString());
				buildFile = new File(Paths.get(pathToProject.substring(0,index+1)) + Paths.get("/").toString() + scanner.nextLine());
			}
			else{
				System.out.println("More than 1 *build.xml files found, please manually input your build file name:");
				int index = pathToProject.lastIndexOf(Paths.get("/").toString());
				buildFile = new File(Paths.get(pathToProject) + Paths.get("/").toString() + scanner.nextLine());
			}
//			System.out.println("Build file: "+buildFile);
			Analyzer analyzer = new Analyzer(buildFile);
//			System.out.println(analyzer.getJunitTarget());
//			System.out.println(analyzer.getTests());
			FileWriter.write(pathToOutput+Paths.get("/")+"includes.txt", analyzer.getIncludes());
			FileWriter.write(pathToOutput+Paths.get("/")+"excludes.txt", analyzer.getExcludes());
			FileWriter.write(pathToOutput+Paths.get("/")+"developer-included-tests.txt", analyzer.getTests());
		}
		
	}

}

