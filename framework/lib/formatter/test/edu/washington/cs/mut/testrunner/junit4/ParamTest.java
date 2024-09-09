package edu.washington.cs.mut.testrunner.junit4;

import static org.junit.Assert.assertTrue;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;
import org.junit.runners.Parameterized.Parameters;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

@RunWith(Parameterized.class)
public class ParamTest {

    private Integer testNo;

    public ParamTest(Integer n) {
        this.testNo = n;
    }

    @Parameters
    public static Collection<Object[]> params() {
        final List<Object[]> list = new ArrayList<Object[]>(3);
        list.add(new Integer[] {1});
        list.add(new Integer[] {2});
        list.add(new Integer[] {3});
        return list;
    }

    @Test
    public void testWithParams() {
        assertTrue(false);
    }
}
