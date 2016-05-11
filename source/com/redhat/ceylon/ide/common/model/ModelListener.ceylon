import com.redhat.ceylon.ide.common.platform {
    platformUtils,
    Status
}
shared interface ModelListener<NativeProject, NativeResource, NativeFolder, NativeFile>
        satisfies ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object 
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
    shared formal void ceylonModelParsed(CeylonProjectAlias project);
    shared formal void ceylonProjectAdded(CeylonProjectAlias project);
    shared formal void ceylonProjectRemoved(CeylonProjectAlias project);
    shared formal void buildMessagesChanged(CeylonProjectAlias project,
        {<CeylonProjectBuildAlias.SourceFileMessage>*}? frontendMessages, 
        {<CeylonProjectBuildAlias.SourceFileMessage>*}? backendMessages, 
        {<CeylonProjectBuildAlias.ProjectMessage>*}? projectMessages);
}

shared interface ModelListenerAdapter<NativeProject, NativeResource, NativeFolder, NativeFile>
        satisfies ModelListener<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object 
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
    shared actual default void ceylonModelParsed(CeylonProjectAlias project) {}
    shared actual default void ceylonProjectAdded(CeylonProjectAlias project) {}
    shared actual default void ceylonProjectRemoved(CeylonProjectAlias project) {}
    shared actual default void buildMessagesChanged(CeylonProjectAlias project,
        {<CeylonProjectBuildAlias.SourceFileMessage>*}? frontendMessages, 
        {<CeylonProjectBuildAlias.SourceFileMessage>*}? backendMessages, 
        {<CeylonProjectBuildAlias.ProjectMessage>*}? projectMessages) {}
}

shared interface ModelListenerDispatcher<NativeProject, NativeResource, NativeFolder, NativeFile>
        satisfies ModelListener<NativeProject, NativeResource, NativeFolder, NativeFile>
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
                forAllListeners(ModelListener.ceylonModelParsed)(project);
        
        shared actual void ceylonProjectAdded(CeylonProjectAlias project) =>
                forAllListeners(ModelListener.ceylonProjectAdded)(project);
        
        shared actual void ceylonProjectRemoved(CeylonProjectAlias project) =>
                forAllListeners(ModelListener.ceylonProjectRemoved)(project);
        
        shared actual void buildMessagesChanged(CeylonProjectAlias project,
            {<CeylonProjectBuildAlias.SourceFileMessage>*}? frontendMessages, 
            {<CeylonProjectBuildAlias.SourceFileMessage>*}? backendMessages, 
            {<CeylonProjectBuildAlias.ProjectMessage>*}? projectMessages)  =>
                forAllListeners(ModelListener.buildMessagesChanged)(project, frontendMessages, backendMessages, projectMessages);
}