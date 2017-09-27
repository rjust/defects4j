package edu.washington.cs.mut.testrunner;

import java.util.List;
import java.util.regex.Pattern;
import java.util.regex.Matcher;

import org.junit.runner.JUnitCore;
import org.junit.runner.Request;
import org.junit.runner.Result;

import org.junit.runner.notification.Failure;

/**
 * Simple JUnit test runner that takes a single test class or test method as
 * command line argument and executes only this class or method.
 *
 * Examples:
 * org.x.y.z.TestClass::testMethod1
 *   -> only testMethod1 in TestClass gets executed
 *
 * org.x.y.z.TestClass
 *   -> only TestClass (with all its test methods) gets executed
 */
public class SingleTestRunner {

    private static void usageAndExit() {
        System.err.println("usage: java " + SingleTestRunner.class.getName() + " testClass[::testMethod]");
        System.exit(1);
    }

    public static void main(String ... args) {
        if (args.length != 1) {
            usageAndExit();
        }
        Matcher m = Pattern.compile("(?<className>[^:]+)(::(?<methodName>[^:]+))?").matcher(args[0]);
        if (!m.matches()) {
            usageAndExit();
        }

        // Determine and load test class
        String className=m.group("className");
        Class<?> clazz = null;
        try {
            clazz = Class.forName(className);
        } catch(Exception e) {
            System.err.println("Couldn't load class (" + className + "): " + e.getMessage());
            System.exit(1);
        }

        // Check whether a test method is provided and create request
        String methodName=m.group("methodName");
        Request req;
        if (methodName == null) {
            req = Request.aClass(clazz);
        } else {
            req = Request.method(clazz, methodName);
        }

        Result res = new JUnitCore().run(req);
        if (!res.wasSuccessful()) {
            System.err.println("Test failed!");
            for (Failure f: res.getFailures()) {
                System.err.println(f.toString());
            }
            System.exit(2);
        }
        // Exit and indicate success. Use System.exit in case any waiting
        // threads are preventing a proper JVM shutdown.
        System.exit(0);
    }
}
