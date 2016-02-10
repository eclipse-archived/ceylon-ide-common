import com.redhat.ceylon.ide.common.completion {
    LinkedModeSupport,
    getAssignableLiterals,
    getSortedProposedValues,
    isIgnoredLanguageModuleValue,
    isIgnoredLanguageModuleMethod,
    isInBounds,
    isIgnoredLanguageModuleClass
}
import ceylon.collection {
    ArrayList,
    MutableList
}
import com.redhat.ceylon.model.typechecker.model {
    NothingType,
    Module,
    Value,
    Function,
    TypeDeclaration,
    Type,
    TypeParameter,
    Constructor,
    Class,
    Unit,
    Scope,
    Declaration
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}

shared interface AbstractInitializerQuickFix<LinkedMode, Document, CompletionResult>
        satisfies LinkedModeSupport<LinkedMode, Document, CompletionResult> {
    
    shared void addInitializer(Document doc,
        DefaultRegion selection, Type? type, Unit unit, Scope scope,
        Integer exitSeq = 0, Integer exitPos = 0) {
        
        value linkedMode = newLinkedMode();
        value proposals = getProposals(doc, selection.start, type, unit, scope);
        
        if (proposals.size > 1) {
            addEditableRegion(linkedMode, doc, selection.start, selection.length,
                0, proposals);
            
            installLinkedMode(doc, linkedMode, this, exitSeq, exitPos);
        }
        
    }
    
    shared formal CompletionResult newNestedLiteralCompletionProposal(
        String val, Integer offset);

    shared formal CompletionResult newNestedCompletionProposal(
        Declaration dec, Integer offset);
    
    CompletionResult[] getProposals(Document document, 
        Integer loc, Type? type, Unit unit, Scope scope) {
        
        value proposals = ArrayList<CompletionResult>();
        
//            //this is totally lame
//            //TODO: see InvocationCompletionProcessor
//            proposals.add(new NestedLiteralCompletionProposal(
//                    document.get(point.x, point.y), point.x));

        addValueArgumentProposals(loc, type, unit, scope, proposals);
        
        return proposals.sequence();
    }

    void addValueArgumentProposals(Integer loc, Type? type,
        Unit unit, Scope scope, MutableList<CompletionResult> props) {
        
        if (!exists type) {
            return;
        }
        
        for (val in getAssignableLiterals(type, unit)) {
            props.add(newNestedLiteralCompletionProposal(val, loc));
        }
        
        value td = type.declaration;
        for (dwp in getSortedProposedValues(scope, unit)) {
            if (dwp.unimported) {
                continue;
            }
            
            value d = dwp.declaration;
            if (is NothingType d) {
                return;
            }
            
            value pname = d.unit.\ipackage.nameAsString;
            value inLangModule = pname.equals(Module.\iLANGUAGE_MODULE_NAME);
            if (is Value d) {
                value \ivalue = d;
                if (inLangModule) {
                    if (isIgnoredLanguageModuleValue(\ivalue)) {
                        continue;
                    }
                }
                
                if (exists vt = \ivalue.type,
                    !vt.nothing,
                    (isTypeParamInBounds(td, vt) || vt.isSubtypeOf(type))) {
                    
                    props.add(newNestedCompletionProposal(d, loc));
                }
            }
            
            if (is Function method=d) {
                if (!d.annotation) {
                    if (inLangModule) {
                        if (isIgnoredLanguageModuleMethod(method)) {
                            continue;
                        }
                    }
                    
                    if (exists mt = method.type,
                        !mt.nothing,
                        (isTypeParamInBounds(td, mt) || mt.isSubtypeOf(type))) {
                        
                        props.add(newNestedCompletionProposal(d, loc));
                    }
                }
            }
            
            if (is Class d) {
                value clazz = d;
                if (!clazz.abstract, !d.annotation) {
                    if (inLangModule) {
                        if (isIgnoredLanguageModuleClass(clazz)) {
                            continue;
                        }
                    }
                    
                    if (exists ct = clazz.type,
                        !ct.nothing,
                        (isTypeParamInBounds(td, ct)
                            || ct.declaration.equals(type.declaration)
                            || ct.isSubtypeOf(type))) {
                        
                        if (clazz.parameterList exists) {
                            props.add(newNestedCompletionProposal(d, loc));
                        }
                        
                        for (m in clazz.members) {
                            if (m is Constructor, m.shared, m.name exists) {
                                props.add(newNestedCompletionProposal(m, loc));
                            }
                        }
                    }
                }
            }
        }
    }
    
    Boolean isTypeParamInBounds(TypeDeclaration td, Type t) {
        return (td is TypeParameter) && isInBounds((td).satisfiedTypes, t);
    }
}
