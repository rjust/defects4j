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


public class Analyzer {
	
	private Project project;
	private TargetGetter targetGetter;
	private TestGetter testGetter;
	private PathParser pathParser;
	
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
	
	public String getTests() {
		String tests = "";
		String dir = this.project.getBaseDir().toString()+Paths.get("/")+this.pathParser.parse(testGetter.getTestDir());
		
		String str[] = WildCardResolver.resolveWildCard(this.getIncludes().split("\n"), this.getExcludes().split("\n"), dir);
		for(int i = 0; i<str.length; i++) {
			tests = tests + str[i] + '\n';
		}
		return tests;
	}
	
	public Target getJunitTarget() {
		return targetGetter.getJunitTarget();
	}
	
}
