import ceylon.collection {
    ArrayList
}

import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.ide.common.correct {
    ImportProposals
}
import com.redhat.ceylon.ide.common.platform {
    PlatformServices,
    VfsServices,
    IdeUtils,
    ModelServices,
    CompositeChange,
    TextChange,
    TextEdit,
    CommonDocument,
    DefaultDocument,
    DefaultTextChange,
    DefaultCompositeChange
}
import com.redhat.ceylon.ide.common.util {
    Indents,
    unsafeCast
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node
}

shared object testPlatform satisfies PlatformServices {
    createCompositeChange(String desc)
            => DefaultCompositeChange(desc);
    
    createTextChange(String desc, CommonDocument|PhasedUnit input)
            => if (is DefaultDocument input) then DefaultTextChange(input) else nothing;
    
    shared actual ImportProposals<IFile,ICompletionProposal,IDocument,InsertEdit,TextEdit,TextChange> importProposals<IFile, ICompletionProposal, IDocument, InsertEdit, TextEdit, TextChange>() => nothing;
    
    shared actual Indents<IDocument> indents<IDocument>()
            => unsafeCast<Indents<IDocument>>(testIndents);
    
    shared actual ModelServices<NativeProject,NativeResource,NativeFolder,NativeFile> model<NativeProject, NativeResource, NativeFolder, NativeFile>() => nothing;
    
    shared actual IdeUtils utils() => nothing;
    
    shared actual VfsServices<NativeProject,NativeResource,NativeFolder,NativeFile> vfs<NativeProject, NativeResource, NativeFolder, NativeFile>() => nothing;
}

shared object testIndents satisfies Indents<DefaultDocument> {
    getDefaultLineDelimiter(DefaultDocument? document) 
            => document?.getDefaultLineDelimiter() else "\n";
    
    getLine(Node node, DefaultDocument doc)
            => doc.getLineContent(doc.getLineOfOffset(node.startIndex.intValue()));
    
    indentSpaces => 4;
    
    indentWithSpaces => true;
}
