import ceylon.collection {
    MutableSet
}

import com.redhat.ceylon.ide.common.util {
    ImmutableSetWrapper
}

import test.ceylon.collection {
    MutableSetTests,
    HashOrderIterableTests
}

shared class ImmutableSetWrapperTest() 
        satisfies MutableSetTests & HashOrderIterableTests {
    
    shared actual MutableSet<T> createSet<T>({T*} elts) given T satisfies Object
            => ImmutableSetWrapper<T>(set(elts));
    
    createCategory = createSet<String>;
    createIterable = createSet<String>;
}
