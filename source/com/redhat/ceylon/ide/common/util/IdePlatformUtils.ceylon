import java.lang {
    RuntimeException
}
shared class Status of _OK | _INFO | _WARNING | _ERROR {
    String _string;
    shared new _OK { _string = "OK"; }
    shared new _INFO  { _string = "INFO"; }
    shared new _WARNING  { _string = "WARNING"; }
    shared new _ERROR  { _string = "ERROR"; }
    string => _string;
}

shared interface IdePlatformUtils {
    shared void register() {
        _platformUtils = this;
    }
    
    shared formal void log(Status status, String message, Exception? e=null);
    
    "Creates a [[RuntimeException|java.lang::RuntimeException]]
     with the exception type typically used in an IDE platform in case of 
     operation cancellation."
    shared formal RuntimeException newOperationCanceledException(String message);
}

shared class DefaultPlatformUtils() satisfies IdePlatformUtils {
    shared actual void log(Status status, String message, Exception? e) {
        Anything(String) printFunction;
        switch (status)
        case( Status._WARNING | Status._ERROR) {
            printFunction = process.writeErrorLine;
        }
        case( Status._INFO | Status._OK) {
            printFunction = process.writeLine;
        }
        
        printFunction("``status``: ``message``");
    }
    
    shared actual RuntimeException newOperationCanceledException(String message) => 
            RuntimeException("Operation Cancelled : ``message``");
}

variable IdePlatformUtils _platformUtils = DefaultPlatformUtils();

shared IdePlatformUtils platformUtils => _platformUtils;