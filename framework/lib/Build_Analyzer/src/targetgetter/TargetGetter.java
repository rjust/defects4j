package targetgetter;

import java.util.ArrayList;
import java.util.Enumeration;
import java.util.List;
import java.util.Vector;

import org.apache.tools.ant.Target;
import org.apache.tools.ant.Task;

import util.Debugger;
import util.TaskHelper;


public class TargetGetter {
	private Vector sortedTargets;
	private ArrayList<Target> potentialSrcTargets, potentialTestTargets;
	
	public TargetGetter(Vector sortedTargets) {
		this.sortedTargets = sortedTargets;
		this.potentialSrcTargets = new ArrayList<Target>();
		this.potentialTestTargets = new ArrayList<Target>();
		this.getCompileTargets();
	}
	
	
	/**
	 * get compile source target
	 * @return
	 */
	public Target getCompileTarget() {
		if(potentialSrcTargets.size() == 0) {
			Debugger.log("Cannot find target that compiles source.");
			return null;
		}
		else if(potentialSrcTargets.size() > 1) {
			Debugger.log("Special case, there might be a top-level compile target.  Requires manual inference.");
			for(Target t : potentialSrcTargets) {
				if(t.getName().contains("compile")) {
					if(t.getName().equals("compile") || t.getName().contains("all"))
						return t;
					else
						return potentialSrcTargets.get(potentialSrcTargets.size()-1);
				}
			}
		}
		return potentialSrcTargets.get(0);
	}
	
	/**
	 * get compile test target
	 * @return
	 */
	public Target getCompileTestTarget() {
		if(potentialTestTargets.size() == 0 && potentialSrcTargets.size() == 1) {
			Target target = potentialSrcTargets.get(0);
			if(TaskHelper.getTasks("javac", target).size()>1) {
				return target;
			}
		}
		return potentialTestTargets.get(potentialTestTargets.size()-1);
	}
	
	/**
	 * get target that contains junit test (suppose to be the target that executes all developer-written tests)
	 * @return
	 */
	public Target getJunitTarget() {
		List<Target> junitTargets = this.getTargets("junit");
		if(junitTargets.size() == 1)
			return junitTargets.get(0);
		else if(junitTargets.size() == 0) {
			Debugger.log("There are no target that contains junit.");
			return null;
		}
		else {
			Debugger.log("There are more than one targets that contains junit.");
			for(Target target:junitTargets) {
				if(target.getName().equals("test"))
					return target;
				if(target.getName().contains("all"))
					return target;
			}
			//if cannot infer which junit target executes all test, get the one that executes first.
			return junitTargets.get(0);
		}
	}
	
	
	/**
	 * helper method that differentiates compile targets and test targets.
	 * 
	 */
	private void getCompileTargets(){
		List<Target> javacTargets = this.getTargets("javac");
		for(Target t : javacTargets) {
			if(t.getName().contains("test")) {
				this.potentialTestTargets.add(t);
			}
			else {
				this.potentialSrcTargets.add(t);
			}
		}
	}
	
	//Returns a list of targets that contains certain task name
	private ArrayList<Target> getTargets(String targetOfInterest){
		ArrayList<Target> list = new ArrayList<Target>();
		Enumeration vEnum = sortedTargets.elements();
		while(vEnum.hasMoreElements()) {
			Target target = (Target) vEnum.nextElement();
			for(Task task :target.getTasks()) {
				if(task.getTaskName().equalsIgnoreCase(targetOfInterest))
					list.add(target);
			}
		}
		return list;
	}
	
}
