import com.redhat.ceylon.ide.common.platform {
    platformUtils,
    Status
}
shared interface ModelListener<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object 
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
    shared formal void ceylonModelParsed(CeylonProject<NativeProject, NativeResource, NativeFolder, NativeFile> project);
    shared formal void ceylonProjectAdded(CeylonProject<NativeProject, NativeResource, NativeFolder, NativeFile> project);
    shared formal void ceylonProjectRemoved(CeylonProject<NativeProject, NativeResource, NativeFolder, NativeFile> project);
}

shared interface ModelListenerAdapter<NativeProject, NativeResource, NativeFolder, NativeFile>
        satisfies ModelListener<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object 
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
    shared actual default void ceylonModelParsed(CeylonProject<NativeProject, NativeResource, NativeFolder, NativeFile> project) {}
    shared actual default void ceylonProjectAdded(CeylonProject<NativeProject, NativeResource, NativeFolder, NativeFile> project) {}
    shared actual default void ceylonProjectRemoved(CeylonProject<NativeProject, NativeResource, NativeFolder, NativeFile> project) {}
}

shared interface ModelListenerDispatcher<NativeProject, NativeResource, NativeFolder, NativeFile>
        satisfies ModelListener<NativeProject, NativeResource, NativeFolder, NativeFile>
        & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object 
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
    shared formal {ModelListenerAlias*} modelListeners;

    Anything(*Arguments) forAllListeners<Arguments>(Anything(*Arguments)(ModelListenerAlias) listenerMethod)
            given Arguments satisfies Anything[] => flatten(
        (Arguments args) =>
                modelListeners.each((listener) {
                    try {
                        unflatten(listenerMethod(listener));
                    } catch(Exception e) {
                        platformUtils.log(Status._ERROR, "A Ceylon Model listener (``listener``) has triggered the following exception:", e);
                    }
                }));
        
        shared actual void ceylonModelParsed(CeylonProjectAlias project) =>
                forAllListeners(ModelListenerAlias.ceylonModelParsed)(project);
        
        shared actual void ceylonProjectAdded(CeylonProjectAlias project) =>
                forAllListeners(ModelListenerAlias.ceylonProjectAdded)(project);
        
        shared actual void ceylonProjectRemoved(CeylonProjectAlias project) =>
                forAllListeners(ModelListenerAlias.ceylonProjectRemoved)(project);
}