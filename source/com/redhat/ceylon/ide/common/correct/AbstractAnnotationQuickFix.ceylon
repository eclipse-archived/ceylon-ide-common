import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.ide.common.util {
    Indents
}

shared interface AbstractAnnotationQuickFix<IDocument,TextEdit,TextChange,Region,Project> {
    shared formal Indents<IDocument> indents;
    
    shared formal Region newRegion(Integer start, Integer length);
    
    shared formal Integer getTextEditOffset(TextEdit change);
    
    shared formal List<PhasedUnit> getUnits(Project p);
    
    shared formal TextChange newTextChange(PhasedUnit u);
}