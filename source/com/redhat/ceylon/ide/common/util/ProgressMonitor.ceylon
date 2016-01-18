import com.redhat.ceylon.model.typechecker.model {
    Cancellable
}
shared interface ProgressMonitor satisfies Cancellable {
    shared formal variable Integer workRemaining;
    shared formal void worked(Integer amount);
}