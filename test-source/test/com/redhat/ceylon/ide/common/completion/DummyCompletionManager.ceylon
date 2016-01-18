import com.redhat.ceylon.cmr.api {
    ModuleVersionDetails,
    ModuleSearchResult
}
import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import com.redhat.ceylon.ide.common.completion {
    IdeCompletionManager
}
import com.redhat.ceylon.ide.common.model {
    CeylonProject,
    BaseCeylonProject
}
import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import com.redhat.ceylon.ide.common.util {
    BaseProgressMonitor,
    Indents
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Unit,
    Package,
    Type,
    Scope,
    Reference
}

import java.util {
    JList=List
}
import java.util.regex {
    Pattern
}

import org.antlr.runtime {
    CommonToken
}
import com.redhat.ceylon.ide.common.settings {
    CompletionOptions
}

class Result(shared String kind, shared String insertedText, shared String description = insertedText) {
    shared actual String string => "``kind``[``insertedText``"
                                 + "``if (description != insertedText) then "(" + description + ")" else ""``]";
    
    shared actual Boolean equals(Object that) {
        if (is Result that) {
            return kind==that.kind && 
                insertedText==that.insertedText && 
                description==that.description;
        }
        else {
            return false;
        }
    }
}

class CompletionData(String code, PhasedUnit pu) satisfies LocalAnalysisResult<String> {
    shared actual BaseCeylonProject? ceylonProject => nothing;
    
    shared actual String document => code;
    
    shared actual PhasedUnit lastPhasedUnit => pu;
    
    shared actual Tree.CompilationUnit lastCompilationUnit => pu.compilationUnit;
    shared actual Tree.CompilationUnit parsedRootNode => lastCompilationUnit;
    shared actual Tree.CompilationUnit? typecheckedRootNode => lastCompilationUnit;
    
    shared actual JList<CommonToken>? tokens => pu.tokens;
    
    suppressWarnings("expressionTypeNothing")
    shared actual TypeChecker typeChecker => nothing;
    
    shared actual CompletionOptions options = CompletionOptions();
}

object dummyMonitor satisfies BaseProgressMonitor {
    shared actual void subTask(String? desc) {}
    shared actual variable Integer workRemaining = 0;
    shared actual void worked(Integer amount) {}
    shared actual Boolean cancelled => false;
}

object dummyCompletionManager extends IdeCompletionManager<CompletionData,Result,String>() {

    shared actual String getDocumentSubstring(String doc, Integer start, Integer length)
            => doc.span(start, start + length - 1);
    
    shared actual Indents<String> indents = object satisfies Indents<String> {
        shared actual String getDefaultLineDelimiter(String? document) => "\n";
        shared actual String getLine(Node node, String doc) => "";
        shared actual Integer indentSpaces => 0;
        shared actual Boolean indentWithSpaces => true;
    };
    
    shared actual Result newAnonFunctionProposal(Integer offset, Type? requiredType, Unit unit, 
        String text, String header, Boolean isVoid, Integer start, Integer len)
            => Result("newAnonFunctionProposal", text);
    
    shared actual Result newBasicCompletionProposal(Integer offset, String prefix, String text,
        String escapedText, Declaration decl, CompletionData cmp)
            => Result("newBasicCompletionProposal", escapedText, text);
    
    shared actual Result newControlStructureCompletionProposal(Integer offset, String prefix,
        String desc, String text, Declaration dec, CompletionData cpc, Node? node)
            => Result("newControlStructureCompletionProposal", desc, text);

    shared actual Result newCurrentPackageProposal(Integer offset, String prefix, String packageName, CompletionData cmp)
            => Result("newCurrentPackageProposal", packageName);
    
    shared actual Result newFunctionCompletionProposal(Integer offset, String prefix, String desc, String text,
        Declaration dec, Unit unit, CompletionData cmp)
            => Result("newFunctionCompletionProposal", text, desc);
    
    shared actual Result newImportedModulePackageProposal(Integer offset, String prefix, String memberPackageSubname,
        Boolean withBody, String fullPackageName, CompletionData controller, Package candidate)
            => Result("newImportedModulePackageProposal", memberPackageSubname, fullPackageName);
    
    shared actual Result newJDKModuleProposal(Integer offset, String prefix, Integer len, String versioned, String name) 
            => Result("newJDKModuleProposal", versioned);
    
    shared actual Result newKeywordCompletionProposal(Integer offset, String prefix, String keyword, String text) 
            => Result("newKeywordCompletionProposal", keyword, text);
    
    shared actual Result newMemberNameCompletionProposal(Integer offset, String prefix, String name, String unquotedName)
            => Result("newMemberNameCompletionProposal", unquotedName, name);
    
    shared actual Result newModuleDescriptorProposal(Integer offset, String prefix, String desc, String text,
        Integer selectionStart, Integer selectionEnd)
            => Result("newModuleDescriptorProposal", text, desc);
    
    shared actual Result newModuleProposal(Integer offset, String prefix, Integer len, String versioned,
        ModuleSearchResult.ModuleDetails mod, Boolean withBody, ModuleVersionDetails version, String name,
        Node node, CompletionData data)
            => Result("newModuleProposal", versioned, name);
    
    shared actual Result newInvocationCompletion(Integer offset, String prefix,
        String desc, String text, Declaration dec, Reference? pr, Scope scope, CompletionData data,
        Boolean includeDefaulted, Boolean positionalInvocation, Boolean namedInvocation, 
        Boolean inheritance, Boolean qualified, Declaration? qualifyingDec)
            => Result("newNamedInvocationCompletion", text, desc);
    
    shared actual Result newPackageDescriptorProposal(Integer offset, String prefix, String desc, String text)
            => Result("newPackageDescriptorProposal", text, desc);
    
    suppressWarnings("expressionTypeNothing")
    shared actual Result newParameterInfo(Integer offset, Declaration dec, Reference producedReference, Scope scope,
        CompletionData cpc, Boolean namedInvocation)
            => nothing; // not supported
    
    shared actual Result newParametersCompletionProposal(Integer offset, String prefix, String desc, String text,
        JList<Type> argTypes, Node node, Unit unit)
            => Result("newParametersCompletionProposal", text, desc);
    
    shared actual Result newQueriedModulePackageProposal(Integer offset, String prefix, String memberPackageSubname,
        Boolean withBody, String fullPackageName, CompletionData controller, ModuleVersionDetails version, Unit unit,
        ModuleSearchResult.ModuleDetails md)
            => Result("newQueriedModulePackageProposal", memberPackageSubname);
    
    shared actual Result newRefinementCompletionProposal(Integer offset, String prefix, Reference? pr,
        String desc, String text, CompletionData cmp, Declaration dec, Scope scope,
        Boolean fullType, Boolean explicitReturnType)
            => Result("newRefinementCompletionProposal", text, desc);
    
    shared actual List<Pattern> proposalFilters => empty;
    
    shared actual Result newTypeProposal(Integer offset, Type? type, String text, String desc, Tree.CompilationUnit rootNode)
            => Result("newTypeProposal", text, desc);
    
        
}
