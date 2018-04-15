package util;

import java.util.ArrayList;
import java.util.List;
import java.util.Enumeration;
import java.util.Set;
import java.util.HashSet;
import java.util.Hashtable;

import org.apache.tools.ant.Target;
import org.apache.tools.ant.Task;
import org.apache.tools.ant.RuntimeConfigurable;

/**
 * TaskHelper provides convinient methods for task related operations.
*/
public class TaskHelper {

	//Get all specified tasks within the target
	public static List<Task> getTasks(String taskType, Target target){
		if(target == null) {
			Debugger.log("target is null when trying to get task.");
			return null;
		}
		Task[] tasks = target.getTasks();
		List<Task> tasksOfInterest = new ArrayList<Task>();
		if(taskType == "") {
			Debugger.log("taskType is empty, please input valid taskType");
		}
		for(Task t : tasks) {
			if(t.getTaskName().equals(taskType)) {
				tasksOfInterest.add(t);
			}
		}
		if(tasksOfInterest.size() == 0)
			Debugger.log("No task: "+taskType+" found under "+target.getName()+", returning null");
		return tasksOfInterest;
	}

	//Get all attrigutes given a task
	public static Hashtable getAttributes(Task t){
		RuntimeConfigurable rt =t.getRuntimeConfigurableWrapper();
		Hashtable att_map = rt.getAttributeMap();
		return att_map;
	}

	//Recursively get all subtasks under a list of rt wrappers
	public static void getSubTask(String taskName, Enumeration<RuntimeConfigurable> subTasks, List<RuntimeConfigurable> list) {
		if(!subTasks.hasMoreElements())
			return;
		while(subTasks.hasMoreElements()) {
			RuntimeConfigurable temp = subTasks.nextElement();
			if(temp.getElementTag().equalsIgnoreCase(taskName))
				list.add(temp);
			getSubTask(taskName, temp.getChildren(), list);
		}

	}

	// Given an attribute name, find all values from a RuntimeConfigurable list,
	// and remove duplicates.
	public static String getValFromAttrMap(List<RuntimeConfigurable> ls, String attr){
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
}
