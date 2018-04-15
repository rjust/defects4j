package util;

import java.util.ArrayList;
import java.util.Enumeration;
import java.util.List;

import org.apache.tools.ant.Target;
import org.apache.tools.ant.Task;
import org.apache.tools.ant.RuntimeConfigurable;

import util.TaskHelper;

public class DirectoryHelper {

  private PathParser pp;
  private List<RuntimeConfigurable> pathelement;

	public DirectoryHelper(PathParser pp) {
		this.pp = pp;
    pathelement = new ArrayList<RuntimeConfigurable>();
	}

  public String getDirectory(String taskType, String dirType, Target target) {
    String ret = "";
    for(Task t : TaskHelper.getTasks(taskType, target)) {
			if(t.getTaskType().equals(taskType)) {
				String dir = (String)TaskHelper.getAttributes(t).get(dirType);
				if(dir == null) {
          Enumeration<RuntimeConfigurable> javacSubTasks = t.getRuntimeConfigurableWrapper().getChildren();
          TaskHelper.getSubTask("pathelement", javacSubTasks, pathelement);
          dir = TaskHelper.getValFromAttrMap(pathelement, "location");
          ret = dir.substring(0, dir.length()-1);
				}else {
          ret = dir;
				}
			}
		}
    return ret;
	}
}
