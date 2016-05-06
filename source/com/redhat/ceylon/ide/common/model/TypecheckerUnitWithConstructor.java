package com.redhat.ceylon.ide.common.model;

import java.util.Collections;

import com.redhat.ceylon.compiler.typechecker.analyzer.ModuleSourceMapper;
import com.redhat.ceylon.compiler.typechecker.context.TypecheckerUnit;
import com.redhat.ceylon.model.typechecker.model.Module;
import com.redhat.ceylon.model.typechecker.model.Package;

public class TypecheckerUnitWithConstructor extends TypecheckerUnit {
    public TypecheckerUnitWithConstructor(
            String theFilename,
            String theRelativePath,
            String theFullPath,
            Package thePackage) {
        super(null, null);
        setFilename(theFilename);
        setRelativePath(theRelativePath);
        setFullPath(theFullPath);
        setPackage(thePackage);
    }

    public TypecheckerUnitWithConstructor(ModuleSourceMapper moduleSourceMapper) {
        super(Collections.<Module>emptyList(), moduleSourceMapper);
    }

    @Override
    public Package getJavaLangPackage() {
        return super.getJavaLangPackage();
    }
}
