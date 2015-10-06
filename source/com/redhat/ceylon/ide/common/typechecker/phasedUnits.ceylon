import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.model.typechecker.util {
    ModuleManager
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit,
    PhasedUnits,
    TypecheckerUnit
}
import com.redhat.ceylon.model.typechecker.model {
    Package,
    Unit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.vfs {
    FolderVirtualFile,
    FileVirtualFile,
    ZipEntryVirtualFile,
    ZipFileVirtualFile
}

import java.lang.ref {
    WeakReference
}
import java.util {
    JList=List,
    WeakHashMap
}

import org.antlr.runtime {
    CommonToken
}
import com.redhat.ceylon.ide.common.util {
    synchronize
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    ModuleSourceMapper
}
import com.redhat.ceylon.ide.common.model {
    CeylonProject,
    IdeModule
}



"Provisional version of the class, in order to be able to compile ModulesScanner"
// TODO Finish the class
shared class EditedPhasedUnit<NativeResource, NativeFolder, NativeFile>(
    FileVirtualFile<NativeResource, NativeFolder, NativeFile> unitFile,
    FolderVirtualFile<NativeResource, NativeFolder, NativeFile> srcDir,
    Tree.CompilationUnit cu,
    Package p,
    ModuleManager moduleManager,
    ModuleSourceMapper moduleSourceMapper,
    TypeChecker typeChecker,
    JList<CommonToken> tokens)
        extends IdePhasedUnit(
        unitFile,
        srcDir,
        cu,
        p,
        moduleManager,
        moduleSourceMapper,
        typeChecker,
        tokens)
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    shared actual TypecheckerUnit newUnit() => nothing;
}





