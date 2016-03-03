import com.redhat.ceylon.model.typechecker.model {
    Cancellable
}
shared interface BaseProgressMonitor satisfies Cancellable {
    shared formal void updateRemainingWork(Integer remainingWork);
    shared formal void worked(Integer amount);
    shared formal void subTask(String? desc=null);
    shared formal BaseProgressMonitor convert(Integer work=0, String taskName="");
    shared formal BaseProgressMonitor newChild(Integer work, Boolean prependMainLabelToSubtask = false);
    shared formal void done();
}

shared abstract class ProgressMonitor<out NativeMonitor>()
    satisfies BaseProgressMonitor {
    formal shared NativeMonitor wrapped;
    shared formal actual ProgressMonitor<NativeMonitor> convert(Integer work, String taskName);
    shared formal actual ProgressMonitor<NativeMonitor> newChild(Integer work, Boolean prependMainLabelToSubtask);
}