import com.redhat.ceylon.ide.common.correct {
    ImportProposals
}

shared interface PlatformServices {
    shared void register() {
        _platformServices = this;
    }
    
    shared formal ModelServices<NativeProject, NativeResource, NativeFolder, NativeFile> model<NativeProject, NativeResource, NativeFolder, NativeFile>();
    shared formal IdeUtils utils();
    shared formal ImportProposals<IFile,ICompletionProposal,IDocument,InsertEdit,TextEdit,TextChange>
    importProposals<IFile,ICompletionProposal,IDocument,InsertEdit,TextEdit,TextChange>();
    shared formal VfsServices<NativeProject, NativeResource, NativeFolder, NativeFile> vfs<NativeProject, NativeResource, NativeFolder, NativeFile>();
}

suppressWarnings("expressionTypeNothing")
variable PlatformServices _platformServices = object satisfies PlatformServices {
    shared actual ModelServices<NativeProject,NativeResource,NativeFolder,NativeFile> model<NativeProject, NativeResource, NativeFolder, NativeFile>() => nothing;
    shared actual IdeUtils utils() => DefaultIdeUtils();
    shared actual ImportProposals<IFile,ICompletionProposal,IDocument,InsertEdit,TextEdit,TextChange> importProposals<IFile, ICompletionProposal, IDocument, InsertEdit, TextEdit, TextChange>() => nothing;
    shared actual VfsServices<NativeProject,NativeResource,NativeFolder,NativeFile> vfs<NativeProject, NativeResource, NativeFolder, NativeFile>() => nothing;
};

PlatformServices platformServices => _platformServices;
shared IdeUtils platformUtils => platformServices.utils();