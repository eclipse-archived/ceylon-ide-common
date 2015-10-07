import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.ide.common.util {
    Indents
}
import com.redhat.ceylon.ide.common.completion {
    IdeCompletionManager
}

shared interface AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,ICompletionResult=Anything> {
    shared formal Indents<IDocument> indents;
    
    shared formal Region newRegion(Integer start, Integer length);
    
    shared formal Integer getTextEditOffset(TextEdit change);
    
    shared formal List<PhasedUnit> getUnits(Project p);
    
    shared formal TextChange newTextChange(String desc, PhasedUnit|IFile|IDocument u);
    
    shared formal ImportProposals<out Anything,out Anything,IDocument,InsertEdit,TextEdit,TextChange> importProposals;
    
    shared formal IdeCompletionManager<out Anything,out Anything,out ICompletionResult,IDocument> completionManager;
}