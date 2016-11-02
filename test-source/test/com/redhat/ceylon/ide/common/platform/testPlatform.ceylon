import ceylon.interop.java {
    javaClass
}
import ceylon.test {
    beforeTestRun
}

import com.redhat.ceylon.ide.common.platform {
    PlatformServices,
    VfsServices,
    IdeUtils,
    ModelServices,
    CommonDocument,
    NoopLinkedMode,
    JavaModelServices,
    Status
}
import com.redhat.ceylon.model.typechecker.model {
    Unit
}

import java.lang {
    RuntimeException
}

import test.com.redhat.ceylon.ide.common.completion {
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
    class MyException(String message) extends RuntimeException(message) {}

    isExceptionToPropagateInVisitors(Exception exception)
            => false;

    isOperationCanceledException(Exception exception)
            => exception is MyException;

    log(Status status, String message, Exception? e)
            => print("[``status``]: ``message``");

    newOperationCanceledException(String message)
            => MyException(message);

    pluginClassLoader => javaClass<IdeUtils>().classLoader;
}