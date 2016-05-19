import com.redhat.ceylon.ide.common.util {
    Indents
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.model.typechecker.model {
    Unit
}

shared interface PlatformServices {
    shared void register() => _platformServices = this;
    
    shared formal IdeUtils utils();
    shared formal ModelServices<NativeProject, NativeResource, NativeFolder, NativeFile> 
            model<NativeProject, NativeResource, NativeFolder, NativeFile>();
    shared formal VfsServices<NativeProject, NativeResource, NativeFolder, NativeFile> 
            vfs<NativeProject, NativeResource, NativeFolder, NativeFile>();

    deprecated("Prefer [[CommonDocument]] instead.")
    shared formal Indents<IDocument> indents<IDocument>();

    shared formal TextChange createTextChange(String name, CommonDocument|PhasedUnit input);
    shared formal CompositeChange createCompositeChange(String name);
    
    shared formal void gotoLocation(Unit unit, Integer offset, Integer length);
}

suppressWarnings("expressionTypeNothing")
variable PlatformServices _platformServices 
        = object satisfies PlatformServices {
    shared actual ModelServices<NativeProject,NativeResource,NativeFolder,NativeFile> 
            model<NativeProject, NativeResource, NativeFolder, NativeFile>() 
            => nothing;
    shared actual IdeUtils utils() => DefaultIdeUtils();
    shared actual VfsServices<NativeProject,NativeResource,NativeFolder,NativeFile> 
            vfs<NativeProject, NativeResource, NativeFolder, NativeFile>() 
            => nothing;
    shared actual Indents<IDocument> indents<IDocument>() 
            => nothing;
    shared actual TextChange createTextChange(String desc, CommonDocument|PhasedUnit input) 
            => nothing;
    createCompositeChange(String desc) 
            => nothing;
    
    gotoLocation(Unit unit, Integer offset, Integer length) => noop();
};

shared PlatformServices platformServices => _platformServices;
shared IdeUtils platformUtils => platformServices.utils();
