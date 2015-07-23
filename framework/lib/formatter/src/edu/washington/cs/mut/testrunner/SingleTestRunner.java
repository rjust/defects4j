package edu.washington.cs.mut.testrunner;

import org.junit.runner.JUnitCore;
import org.junit.runner.Request;
import org.junit.runner.Result;

/**
 * Simple JUnit test runner that takes a test method as 
 * command line argument and executes only this method.
 *
 * Example:
 * org.x.y.z.TestClass::testMethod1
 *
 * -> only testMethod1 in TestClass gets executed
 */
public class SingleTestRunner {
    public static void main(String... args) {
        try{
            String name=args[0];
            int index = name.indexOf(':');
            String className=name.substring(0,index);
            String methName=name.substring(index+2);

            Request req=null;
            req = Request.method(Class.forName(className), methName);
            Result res = new JUnitCore().run(req);
            if(!res.wasSuccessful()) System.exit(1);
        }catch(Exception e){
            e.printStackTrace();
            System.exit(1);
        }
    }
}
