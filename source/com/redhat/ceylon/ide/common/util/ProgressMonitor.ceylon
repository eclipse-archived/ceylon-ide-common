shared interface BaseProgressMonitor {
    shared formal variable Integer workRemaining;
    shared formal void worked(Integer amount);
    shared formal void subTask(String? desc);
}

shared abstract class ProgressMonitor<NativeMonitor>(shared NativeMonitor wrapped)
    satisfies BaseProgressMonitor {
        
        shared actual variable Integer workRemaining = 0;
        
}