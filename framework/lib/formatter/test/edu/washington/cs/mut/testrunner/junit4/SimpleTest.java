package edu.washington.cs.mut.testrunner.junit4;

import org.junit.Assert;
import org.junit.Test;

public class SimpleTest {
   
    @Test 
	public void test1() {
		Assert.assertTrue(true);
	}
	
    @Test 
    public void test2() {
	    Assert.assertTrue(false);
    }
	
    @Test 
    public void test3() {
		Assert.assertTrue("because it should be true", false);
	}
}
