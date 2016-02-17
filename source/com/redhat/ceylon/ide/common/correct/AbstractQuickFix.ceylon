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

shared interface AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,
        Region,Project,Data,ICompletionResult=Anything>
        given Data satisfies QuickFixData<Project> {

    shared formal Indents<IDocument> indents;
    
    shared formal Region newRegion(Integer start, Integer length);
    
    shared formal Integer getTextEditOffset(TextEdit change);
    
    shared formal List<PhasedUnit> getUnits(Project p);
    
    shared formal TextChange newTextChange(String desc, PhasedUnit|IFile|IDocument u);
    
    shared formal ImportProposals<out Anything,out Anything,IDocument,InsertEdit,TextEdit,TextChange> importProposals;
    
    shared formal IdeCompletionManager<out Anything,out ICompletionResult,IDocument> completionManager;
    
    shared formal PhasedUnit? getPhasedUnit(Unit? u, Data data);
    
    shared formal IFile? getFile<NativeFile>(IResourceAware<out Anything, out Anything, NativeFile> pu, Data data);
}
