package edu.washington.cs.mut.testrunner;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.io.OutputStream;
import java.io.PrintStream;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import junit.framework.AssertionFailedError;
import junit.framework.Test;
import junit.framework.TestSuite;

import org.apache.tools.ant.BuildException;
import org.apache.tools.ant.taskdefs.optional.junit.JUnitResultFormatter;
import org.apache.tools.ant.taskdefs.optional.junit.JUnitTest;

public class Formatter implements JUnitResultFormatter {

	private PrintStream ps;
	private PrintStream allTests;

	{
		try {
			this.ps = new PrintStream(new FileOutputStream(System.getProperty("OUTFILE", "failing-tests.txt"), true), true);
			this.allTests = new PrintStream(new FileOutputStream(System.getProperty("ALLTESTS", "all_tests"), true), true);
		} catch (FileNotFoundException e) {
			throw new RuntimeException(e);
		}
	}
	
	@Override
	public void endTestSuite(JUnitTest arg0) throws BuildException {
	}

	@Override
	public void setOutput(OutputStream arg0) {
	}

	@Override
	public void setSystemError(String arg0) {	
	}

	@Override
	public void setSystemOutput(String arg0) {
	}

	String className ;
	boolean alreadyPrinted = true;
	
	@Override
	public void startTestSuite(JUnitTest junitTest) throws BuildException {
		className = junitTest.getName();
		alreadyPrinted = false;
	}
	

	@Override
	public void addError(Test test, Throwable t) {
		handle(test, t);
	}

	@Override
	public void addFailure(Test test, AssertionFailedError t) {
		handle(test,t);
	}
	
	private void handle(Test test, Throwable t) {
		String prefix = "--- " ;
		String className = null;
		String methodName = null;

		if (test == null) { // if test is null it indicates an initialization error for the class
			failClass(t, prefix);  
			return;
		}
		
		{
			Pattern regexp = Pattern.compile("(.*)\\((.*)\\)");
			Matcher match  = regexp.matcher(test.toString());
			if (match.matches()) {
				className = match.group(2);
				methodName = match.group(1);
			}
		}
		{
			Pattern regexp = Pattern.compile("(.*):(.*)"); // for some weird reson this format is used for Timeout in Junit4
			Matcher match  = regexp.matcher(test.toString());
			if (match.matches()) {
				className = match.group(1);
				methodName = match.group(2);
			}
		}
		
		if ("warning".equals(methodName) || "initializationError".equals(methodName)) {
			failClass(t, prefix); // there is an issue with the class, not the method.
		} else if (null != methodName && null != className) {
			if (isJunit4InitFail(t)) {
				failClass(t, prefix);
			} else {
				ps.println(prefix + className + "::" + methodName); // normal case
				t.printStackTrace(ps);
			}
		} else {
			ps.print(prefix + "broken test input " + test.toString());
			t.printStackTrace(ps);
		}
		
	}

	private void failClass(Throwable t, String prefix) {
		if (!this.alreadyPrinted) {
			ps.println(prefix + this.className);
			t.printStackTrace(ps);
			this.alreadyPrinted = true;
		}
	}

	private boolean isJunit4InitFail(Throwable t) {
		for (StackTraceElement ste: t.getStackTrace()) {
			if ("createTest".equals(ste.getMethodName())) {
				return true;
			}
		}
		return false;
	}

	@Override
	public void endTest(Test test) {
	}

	@Override
	public void startTest(Test test) {
	    allTests.println(test.toString());
	}
}
