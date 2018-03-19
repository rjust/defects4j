package util;

import java.util.ArrayList;
import java.util.List;

import org.apache.tools.ant.Target;
import org.apache.tools.ant.Task;

/**
 * TaskHelper provides convinient methods for task related operations.
*/
public class TaskHelper {

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
}
