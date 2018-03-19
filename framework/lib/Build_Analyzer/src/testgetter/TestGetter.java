package testgetter;

import java.util.ArrayList;
import java.util.Enumeration;
import java.util.HashSet;
import java.util.Hashtable;
import java.util.List;
import java.util.Set;

import org.apache.tools.ant.RuntimeConfigurable;
import org.apache.tools.ant.Target;
import org.apache.tools.ant.Task;

import util.Debugger;
import util.TaskHelper;

/**
 * Class for getting developer included tests from given build file.
 */
public class TestGetter {

	private Target target;
	private List<RuntimeConfigurable> batchTests, filesets, includes, excludes;

	public TestGetter(Target target) {
		this.target = target;
		batchTests = new ArrayList<RuntimeConfigurable>();
		filesets = new ArrayList<RuntimeConfigurable>();
		includes = new ArrayList<RuntimeConfigurable>();
		excludes = new ArrayList<RuntimeConfigurable>();
		this.getPatterns();
	}

	// Get includes pattern from all "includes" attribute
	public String getIncludesPattern() {
		String ret = "";

		if(this.filesets != null) {
			for(RuntimeConfigurable fileset:filesets) {
				if(fileset.getAttributeMap().get("includes") != null)
					ret = ret+fileset.getAttributeMap().get("includes")+"\n";
			}
		}

		if(this.includes != null) {
			for(RuntimeConfigurable include:includes) {
				String temp = (String) include.getAttributeMap().get("name");
				if(include.getAttributeMap().get("name") != null && !temp.contains("$"))
					ret = ret+include.getAttributeMap().get("name")+"\n";
			}
		}
		Debugger.log("includes: "+ret);
		return ret;
	}

	// Get excludes pattern from all "excludes attribute"
	public String getExcludesPattern() {
		String ret = "";
		List <String> list = new ArrayList<String>();
		Set<String> hs = new HashSet<>();
		if(this.filesets != null) {
			for(RuntimeConfigurable fileset:filesets) {
				if(fileset.getAttributeMap().get("excludes") != null)
					list.add((String) fileset.getAttributeMap().get("excludes"));
			}
		}

		if(this.excludes != null) {
			for(RuntimeConfigurable exclude:excludes) {
				String temp = (String) exclude.getAttributeMap().get("name");
				if(exclude.getAttributeMap().get("name") != null )
					list.add((String) exclude.getAttributeMap().get("name"));
			}
		}
//		list = list.stream().distinct().collect(Collectors.toList());
		// Remove duplicates
		hs.addAll(list);
		list.clear();
		list.addAll(hs);
		for(int i=0; i<list.size(); i++) {
			ret = ret + list.get(i) + '\n';
		}
		Debugger.log("excludes: "+ret);
		return ret;
	}

	// Get directory that contains the tests
	public String getTestDir() {
		String dir = "";
		if(filesets != null) {
			for(RuntimeConfigurable fileset:filesets) {
				if(fileset.getAttributeMap().get("dir") != null)
					dir=fileset.getAttributeMap().get("dir")+"";
			}
		}
		return dir;
	}

	// Find fileset, includes, and excludes under junit batchtest.
	// Then store them to the ArrayList.
	private void getPatterns() {
		List<Task> tasks = TaskHelper.getTasks("junit", target);
		for(Task task:tasks) {
			Enumeration<RuntimeConfigurable> junitSubTasks = task.getRuntimeConfigurableWrapper().getChildren();
			this.getSubTask("batchtest", junitSubTasks, batchTests);
			for(RuntimeConfigurable batch : batchTests) {
				this.getSubTask("fileset", batch.getChildren(), filesets);
				this.getSubTask("include", batch.getChildren(), includes);
				this.getSubTask("exclude", batch.getChildren(), excludes);
			}
		}
	}

	//Helper method to recursively get certain subtasks
	private void getSubTask(String taskName, Enumeration<RuntimeConfigurable> subTasks, List<RuntimeConfigurable> list) {
		if(!subTasks.hasMoreElements())
			return;
		while(subTasks.hasMoreElements()) {
			RuntimeConfigurable temp = subTasks.nextElement();
			if(temp.getElementTag().equalsIgnoreCase(taskName))
				list.add(temp);
			getSubTask(taskName, temp.getChildren(), list);
		}

	}

}
