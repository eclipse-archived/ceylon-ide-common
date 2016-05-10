import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.ide.common.util {
    Indents
}
import com.redhat.ceylon.ide.common.completion {
    IdeCompletionManager
}
import com.redhat.ceylon.model.typechecker.model {
    Unit
}
import com.redhat.ceylon.ide.common.model {
    IResourceAware
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}

shared interface AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,
        Region,Data,ICompletionResult=Anything>
        given Data satisfies QuickFixData {

    shared formal Indents<IDocument> indents;
    
    shared formal Region newRegion(Integer start, Integer length);
    
    shared formal Integer getTextEditOffset(TextEdit change);
    
    //shared formal List<PhasedUnit> getUnits(Project p);
    
    shared formal TextChange newTextChange(String desc, PhasedUnit|IFile|IDocument u);
    
    shared formal ImportProposals<out Anything,out Anything,IDocument,InsertEdit,TextEdit,TextChange> importProposals;
    
    shared formal IdeCompletionManager<out Anything,out ICompletionResult,IDocument> completionManager;
    
    shared formal PhasedUnit? getPhasedUnit(Unit? u, Data data);
    
    shared formal IFile? getFile<NativeFile>(IResourceAware<out Anything, out Anything, NativeFile> pu, Data data);
}

shared interface GenericQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData {

    shared formal void newProposal(Data data, String desc, TextChange change,
        DefaultRegion? region = null);
}