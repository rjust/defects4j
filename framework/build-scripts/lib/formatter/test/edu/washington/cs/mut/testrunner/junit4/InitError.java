package edu.washington.cs.mut.testrunner.junit4;

import org.junit.Assert;
import org.junit.Test;

public class InitError {

	public InitError() {
	    throw new RuntimeException("Constructor failed");	
	}
	
    @Test
	public void test1() {
		Assert.assertTrue(true);
	}
    
    @Test
	public void test2() {
		Assert.assertTrue("because it should be true", false);
	}
    
    @Test
	public void test3() {
		Assert.assertTrue("because it should be true", false);
	}
}
