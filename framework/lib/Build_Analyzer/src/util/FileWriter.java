package util;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.UnsupportedEncodingException;
import java.io.Writer;

public class FileWriter {
	
	private FileWriter() {
		
	}
	
	public static void write(String string, String data) throws UnsupportedEncodingException, FileNotFoundException, IOException {
		try (Writer writer = new BufferedWriter(new OutputStreamWriter(
	        new FileOutputStream(string), "utf-8"))) {
				writer.write(data);
			}
	}
}
