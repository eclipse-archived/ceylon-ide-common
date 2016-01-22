package com.redhat.ceylon.ide.common.model;

import com.redhat.ceylon.compiler.typechecker.context.TypecheckerUnit;
import com.redhat.ceylon.model.typechecker.model.Package;

public class TypecheckerUnitWithConstructor extends TypecheckerUnit {
    public TypecheckerUnitWithConstructor(
            String theFilename,
            String theRelativePath,
            String theFullPath,
            Package thePackage) {
        super();
        setFilename(theFilename);
        setRelativePath(theRelativePath);
        setFullPath(theFullPath);
        setPackage(thePackage);
    }
    public TypecheckerUnitWithConstructor() {
        super();
    }
}
