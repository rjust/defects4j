package edu.washington.cs.mut.testrunner.junit3;

import org.junit.Assert;
import junit.framework.TestCase;

public abstract class AbstractTestClass extends TestCase {

	public void test1() {
		Assert.assertTrue(true);
	}
	
    public void test2() {
		Assert.assertTrue(true);
	}
	
    public void test3() {
		Assert.assertTrue("because it should be true", false);
	}
}
