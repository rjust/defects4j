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
	private List<RuntimeConfigurable> batchTests, tests, filesets, includes, excludes;

	public TestGetter(Target target) {
		this.target = target;
		batchTests = new ArrayList<RuntimeConfigurable>();
		tests = new ArrayList<RuntimeConfigurable>();
		filesets = new ArrayList<RuntimeConfigurable>();
		includes = new ArrayList<RuntimeConfigurable>();
		excludes = new ArrayList<RuntimeConfigurable>();
		this.getPatterns();
	}

	// Get includes pattern from all "includes" attribute
	public String getIncludesPattern() {
		String ret = "";
		ret = ret + getValFromAttrMap(filesets, "includes");
		ret = ret + getValFromAttrMap(includes, "name");
		ret = ret + getValFromAttrMap(tests, "name");
		Debugger.log("includes: "+ret);
		return ret;
	}

	// Get excludes pattern from all "excludes attribute"
	public String getExcludesPattern() {
		String ret = "";
		List <String> list = new ArrayList<String>();
		Set<String> hs = new HashSet<>();
		ret = ret + getValFromAttrMap(filesets, "excludes");
		ret = ret + getValFromAttrMap(excludes, "name");
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

	// Given an attribute name, find all values from a RuntimeConfigurable list,
	// and remove duplicates.
	private String getValFromAttrMap(List<RuntimeConfigurable> ls, String attr){
		String ret = "";
		List <String> list = new ArrayList<String>();
		Set<String> hs = new HashSet<>();
		for(RuntimeConfigurable rt:ls) {
			if(rt.getAttributeMap().get(attr) != null)
				list.add((String)rt.getAttributeMap().get(attr));
		}
		hs.addAll(list);
		list.clear();
		list.addAll(hs);
		for(int i=0; i<list.size(); i++) {
			ret = ret + list.get(i) + '\n';
		}
		return ret;
	}

	// 1. Find fileset, includes, and excludes under junit batchtest.
	// 2. If no batchtest exists, find <test> sub task instead.
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
			junitSubTasks = task.getRuntimeConfigurableWrapper().getChildren();
			this.getSubTask("test", junitSubTasks, tests);
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
