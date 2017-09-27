import ceylon.test {
    beforeTestRun
}

import org.eclipse.ceylon.ide.common.platform {
    PlatformServices,
    VfsServices,
    IdeUtils,
    ModelServices,
    CommonDocument,
    NoopLinkedMode,
    JavaModelServices,
    Status
}
import org.eclipse.ceylon.model.typechecker.model {
    Unit
}

import java.lang {
    Types
}

import test.org.eclipse.ceylon.ide.common.completion {
    testCompletionServices
}

beforeTestRun
void setupTests() {
    testPlatform.register();
}

shared object testPlatform satisfies PlatformServices {
    
    shared actual ModelServices<NativeProject,NativeResource,NativeFolder,NativeFile> model<NativeProject, NativeResource, NativeFolder, NativeFile>() => nothing;
    
    utils() => testIdeUtils;
    
    shared actual VfsServices<NativeProject,NativeResource,NativeFolder,NativeFile> vfs<NativeProject, NativeResource, NativeFolder, NativeFile>() => nothing;
    
    gotoLocation(Unit unit, Integer offset, Integer length) => null;
    
    createLinkedMode(CommonDocument document)
            => NoopLinkedMode(document);
    
    completion => testCompletionServices;
    document => testDocumentServices;
    
    shared actual JavaModelServices<JavaClassRoot> javaModel<JavaClassRoot>() => nothing;
}

object testIdeUtils satisfies IdeUtils {
    class MyException(String message) extends Exception(message) {}

    isExceptionToPropagateInVisitors(Exception exception)
            => false;

    isOperationCanceledException(Exception exception)
            => exception is MyException;

    log(Status status, String message, Exception? e)
            => print("[``status``]: ``message``");

    newOperationCanceledException(String message)
            => MyException(message);

    pluginClassLoader => Types.classForType<IdeUtils>().classLoader;
}