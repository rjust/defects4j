package util;

/**
 * Enabling debugger will print out a full trace of information logged.
*/
public class Debugger {

	private static boolean enabled = false;

	private Debugger() {

	}

	public static void enable() {
		enabled = true;
	}



	public static void log(String message) {
		if(enabled == true) {
			System.out.println(message);
		}
	}
}
