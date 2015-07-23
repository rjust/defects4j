package edu.washington.cs.mut.testrunner.junit4;

import org.junit.Test;

public class MethodTimeout {

	
	@Test public void test1() {
		// this passes
	}
	
	@Test(timeout=1000) public void test2()  throws Exception {
		// this fails
		while (true)  { Thread.sleep(100); }
	}
}
