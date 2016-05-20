import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.ide.common.platform {
    PlatformServices,
    VfsServices,
    IdeUtils,
    ModelServices,
    CommonDocument,
    DefaultDocument,
    DefaultTextChange,
    DefaultCompositeChange,
    NoopLinkedMode
}
import com.redhat.ceylon.model.typechecker.model {
    Unit,
    Type
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}

shared object testPlatform satisfies PlatformServices {
    createCompositeChange(String desc)
            => DefaultCompositeChange(desc);
    
    createTextChange(String desc, CommonDocument|PhasedUnit input)
            => if (is DefaultDocument input) then DefaultTextChange(input) else nothing;
    
    shared actual ModelServices<NativeProject,NativeResource,NativeFolder,NativeFile> model<NativeProject, NativeResource, NativeFolder, NativeFile>() => nothing;
    
    shared actual IdeUtils utils() => nothing;
    
    shared actual VfsServices<NativeProject,NativeResource,NativeFolder,NativeFile> vfs<NativeProject, NativeResource, NativeFolder, NativeFile>() => nothing;
    
    gotoLocation(Unit unit, Integer offset, Integer length) => noop();
    
    indentSpaces => 4;
    indentWithSpaces => true;
    createLinkedMode(CommonDocument document)
            => NoopLinkedMode(document);
    
    shared actual Anything getTypeProposals(CommonDocument document,
        Integer offset, Integer length, Type infType,
        Tree.CompilationUnit rootNode, String? kind) => null;
    
}
