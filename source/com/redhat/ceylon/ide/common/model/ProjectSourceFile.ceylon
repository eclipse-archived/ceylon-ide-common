import com.redhat.ceylon.compiler.typechecker.context {
    TypecheckerUnit
}
import com.redhat.ceylon.ide.common.typechecker {
    ProjectPhasedUnit
}
import com.redhat.ceylon.ide.common.model.delta {
    CompilationUnitDelta
}
//TODO : finish it
shared class ProjectSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>(
    ProjectPhasedUnit<NativeProject,NativeResource,NativeFolder,NativeFile> projectPhasedUnit)
        extends ModifiableSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>(projectPhasedUnit)
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    shared actual NativeFile? resourceFile => nothing;
    
    shared actual NativeProject? resourceProject => nothing;
    
    shared actual NativeFolder? resourceRootFolder => nothing;
    
    shared CompilationUnitDelta buildDeltaAgainstModel() => nothing;
}