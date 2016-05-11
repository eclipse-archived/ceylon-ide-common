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
    shared formal void buildMessagesChanged(CeylonProject<NativeProject, NativeResource, NativeFolder, NativeFile> project,
        {<CeylonProjectBuild<NativeProject, NativeResource, NativeFolder, NativeFile>.SourceFileMessage>*}? frontendMessages, 
        {<CeylonProjectBuild<NativeProject, NativeResource, NativeFolder, NativeFile>.SourceFileMessage>*}? backendMessages, 
        {<CeylonProjectBuild<NativeProject, NativeResource, NativeFolder, NativeFile>.ProjectMessage>*}? projectMessages);
}

shared interface ModelListenerAdapter<NativeProject, NativeResource, NativeFolder, NativeFile>
        satisfies ModelListener<NativeProject, NativeResource, NativeFolder, NativeFile>
        & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
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
                        unflatten(listenerMethod(listener))(args);
                    } catch(Throwable t) {
                        value messagePrefix = "A Ceylon Model listener (``listener``) has triggered the following ";
                        if (is Exception e=t) {
                            platformUtils.log(Status._ERROR, messagePrefix + "exception:", e);
                        } else {
                            platformUtils.log(Status._ERROR, messagePrefix + "error: `` t.string ``");
                        }
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