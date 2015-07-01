shared interface ProgressMonitor {
    shared formal variable Integer workRemaining;
    shared formal void worked(Integer amount);
}