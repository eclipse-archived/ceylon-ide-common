package org.eclipse.ceylon.ide.common.debug.agent;

public class DebugAgent {
    public static void premain(String agentArgs) {
        CeylonDebugEvaluationThread.startDebugEvaluationThread();
    }
    public static void agentmain(String agentArgs) {
        CeylonDebugEvaluationThread.startDebugEvaluationThread();
    }
}
