package edu.washington.cs.mut.testrunner.junit3;

import org.junit.Assert;
import junit.framework.TestCase;

public class InitError extends TestCase {

	public InitError() {
	    throw new RuntimeException("Constructor failed");	
	}
	
	public void test1() {
		Assert.assertTrue(true);
	}
	public void test2() {
		Assert.assertTrue("because it should be true", false);
	}
	public void test3() {
		Assert.assertTrue("because it should be true", false);
	}
}
