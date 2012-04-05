
public class HelloCloud {

	public static void main(String[] args) {
                String javaopts = System.getenv("JAVA_OPTS");
                if(javaopts != null) {
                        String userDir = System.getProperty("user.dir");
                        //Strip the /app off the current working dir
                        userDir = userDir.substring(0,userDir.length()-4);
                        javaopts = javaopts.replaceAll(userDir,"appdir");
                }
		System.out.print("Hello from the cloud.  Java opts: " + javaopts);
		while(true) {
			try {
				Thread.sleep(120000);
			} catch (InterruptedException e) {
			}
		}
	}
}
