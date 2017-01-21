import com.redhat.ceylon.ide.common.util {
    BaseProgressMonitorChild,
    BaseProgressMonitor
}

shared class DummyProgressMonitor() satisfies BaseProgressMonitor & BaseProgressMonitorChild {
    shared actual class Progress(Integer estimatedWork, String? taskName)
            extends super.Progress(estimatedWork, taskName) {
        shared actual Boolean cancelled => false;
        shared actual void changeTaskName(String taskDescription) {}
        shared actual void destroy(Throwable? error) {}
        shared actual BaseProgressMonitorChild newChild(Integer allocatedWork) => outer;
        shared actual void subTask(String subTaskDescription) {}
        shared actual void updateRemainingWork(Integer remainingWork) {}
        shared actual void worked(Integer amountOfWork) {}
    }
    shared actual Boolean cancelled => false;
}
shared DummyProgressMonitor dummyProgressMonitor = DummyProgressMonitor();