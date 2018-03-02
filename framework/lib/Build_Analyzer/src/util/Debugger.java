package util;

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
