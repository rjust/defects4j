import java.io.File;
import java.nio.file.Paths;
import java.util.List;

import org.apache.tools.ant.Project;
import org.apache.tools.ant.ProjectHelper;
import org.apache.tools.ant.Target;

import targetgetter.TargetGetter;
import testgetter.TestGetter;
import util.PathParser;
import util.WildCardResolver;
import util.DirectoryHelper;


public class Analyzer {

	private Project project;
	private TargetGetter targetGetter;
	private TestGetter testGetter;
	private PathParser pathParser;
	private DirectoryHelper dirHelper;

	public Analyzer(File buildFile) {

		//Load in build file
		project = new Project();
		project.init();
		ProjectHelper helper = new ProjectHelper();
		helper.configureProject(project, buildFile);

		//Initialize Target getter
		if(project.getDefaultTarget() != null)
			targetGetter = new TargetGetter(project.topoSort(project.getDefaultTarget(), project.getTargets()));
		else
			targetGetter = new TargetGetter(project.topoSort("", project.getTargets()));

		//Initialize Test getter
		testGetter = new TestGetter(targetGetter.getJunitTarget());

		//Initialize Path parser
		pathParser = new PathParser(project);

		//Initialize directory helper
		dirHelper = new DirectoryHelper(pathParser);
	}

	public Target getCompileTarget() {
		return targetGetter.getCompileTarget();
	}

	public Target getCompileTestTarget() {
		return targetGetter.getCompileTestTarget();
	}

	public String getIncludes() {
		return testGetter.getIncludesPattern();
	}

	public String getExcludes() {
		return testGetter.getExcludesPattern();
	}

	//Get all test classes that are executed by developers
	public String getTests() {
		String tests = "";
		//Get project directory that contains test classes using PathParser
		String dir = this.project.getBaseDir().toString()+Paths.get("/")+this.pathParser.parse(testGetter.getTestDir());
		//Get includes and excludes patters, so WildCardResolver can scan through the directory and find all file names
		String str[] = WildCardResolver.resolveWildCard(this.getIncludes().split("\n"), this.getExcludes().split("\n"), dir);
		for(int i = 0; i<str.length; i++) {
			tests = tests + str[i] + '\n';
		}
		return tests;
	}

	public Target getJunitTarget() {
		return targetGetter.getJunitTarget();
	}

	public String getTestDir() {
		
		if(dirHelper.getDirectory("javac", "srcdir", getCompileTestTarget()).split("\n").length > 1)
			return testGetter.getTestDir();
		return dirHelper.getDirectory("javac", "srcdir", getCompileTestTarget());
	}

	public String getSrcDir() {
		return dirHelper.getDirectory("javac", "srcdir", getCompileTarget());
	}

	public String getTestOutputDir() {
		return dirHelper.getDirectory("javac", "destdir", getCompileTestTarget());
	}

	public String getOutputDir() {
		return dirHelper.getDirectory("javac", "destdir", getCompileTarget());
	}

}
