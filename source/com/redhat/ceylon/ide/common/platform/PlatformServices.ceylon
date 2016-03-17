
shared interface PlatformServices {
    shared void register() {
        _platformServices = this;
    }
    
    shared formal ModelServices<NativeProject, NativeResource, NativeFolder, NativeFile> model<NativeProject, NativeResource, NativeFolder, NativeFile>();
    shared formal IdePlatformUtils utils();
}

suppressWarnings("expressionTypeNothing")
variable PlatformServices _platformServices = object satisfies PlatformServices {
    shared actual ModelServices<NativeProject,NativeResource,NativeFolder,NativeFile> model<NativeProject, NativeResource, NativeFolder, NativeFile>() => nothing;
    shared actual IdePlatformUtils utils() => DefaultPlatformUtils();
    
};

shared PlatformServices platformServices => _platformServices;
shared IdePlatformUtils platformUtils => platformServices.utils();