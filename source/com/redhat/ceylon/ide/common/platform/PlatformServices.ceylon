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
    shared formal CompletionServices completion;
    shared formal DocumentServices document;
    shared formal void gotoLocation(Unit unit, Integer offset, Integer length);
    
    shared formal LinkedMode createLinkedMode(CommonDocument document);
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
    completion => nothing;
    document => nothing;
    gotoLocation(Unit unit, Integer offset, Integer length) => noop();
    createLinkedMode(CommonDocument document) => NoopLinkedMode(document);
};

shared PlatformServices platformServices => _platformServices;
shared IdeUtils platformUtils => platformServices.utils();
