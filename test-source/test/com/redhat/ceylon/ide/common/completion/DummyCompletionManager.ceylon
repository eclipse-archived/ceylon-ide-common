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
    CompletionContext,
    ProposalsHolder,
    ProposalKind
}
import com.redhat.ceylon.ide.common.model {
    BaseCeylonProject
}
import com.redhat.ceylon.ide.common.platform {
    CommonDocument,
    DefaultDocument,
    CompletionServices,
    TextChange
}
import com.redhat.ceylon.ide.common.settings {
    CompletionOptions
}
import com.redhat.ceylon.ide.common.util {
    BaseProgressMonitorChild
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
import com.redhat.ceylon.ide.common.doc {
    Icons
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
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

class CompletionData(String code, PhasedUnit pu) satisfies CompletionContext {
    suppressWarnings("expressionTypeNothing")
    shared actual BaseCeylonProject? ceylonProject => nothing;
    
    shared actual PhasedUnit lastPhasedUnit => pu;
    
    shared actual Tree.CompilationUnit lastCompilationUnit => pu.compilationUnit;
    shared actual Tree.CompilationUnit parsedRootNode => lastCompilationUnit;
    shared actual Tree.CompilationUnit? typecheckedRootNode => lastCompilationUnit;
    
    shared actual JList<CommonToken> tokens => pu.tokens;
    
    suppressWarnings("expressionTypeNothing")
    shared actual TypeChecker typeChecker => nothing;
    
    shared actual CompletionOptions options = CompletionOptions();
    
    shared actual CommonDocument commonDocument => DefaultDocument(code);
    
    shared actual MyProposalsHolder proposals = MyProposalsHolder();
    
    shared actual List<Pattern> proposalFilters => empty;
    
}

class MyProposalsHolder() satisfies ProposalsHolder {
    size => 0;
}

object dummyMonitor satisfies BaseProgressMonitorChild {
    shared actual Boolean cancelled => false;
    shared actual class Progress(Integer estimatedWork, String? taskName)
             extends super.Progress(estimatedWork, taskName) {
        shared actual Boolean cancelled => outer.cancelled;
        shared actual void changeTaskName(String taskDescription) {}
        shared actual void destroy(Throwable? error) {}
        shared actual BaseProgressMonitorChild newChild(Integer allocatedWork) => outer;
        shared actual void subTask(String subTaskDescription) {}
        shared actual void updateRemainingWork(Integer remainingWork) {}
        shared actual void worked(Integer amount) {}
    }
    
}

class MyCompletionService() satisfies CompletionServices {
    
    shared actual void newControlStructureCompletionProposal(Integer offset, String prefix,
        String desc, String text, Declaration dec, CompletionContext ctx, Node? node)
            => Result("newControlStructureCompletionProposal", desc, text);
    
    shared actual void newFunctionCompletionProposal(Integer offset, String prefix, String desc, String text,
        Declaration dec, Unit unit, CompletionContext ctx)
            => Result("newFunctionCompletionProposal", text, desc);
    
    shared actual void newImportedModulePackageProposal(Integer offset, String prefix, String memberPackageSubname,
        Boolean withBody, String fullPackageName, CompletionContext ctx, Package candidate)
            => Result("newImportedModulePackageProposal", memberPackageSubname, fullPackageName);
    
    shared actual void newJDKModuleProposal(CompletionContext ctx, Integer offset, String prefix, Integer len, String versioned, String name) 
            => Result("newJDKModuleProposal", versioned);
    
    shared actual void newModuleDescriptorProposal(CompletionContext ctx, Integer offset, String prefix, String desc, String text,
        Integer selectionStart, Integer selectionEnd)
            => Result("newModuleDescriptorProposal", text, desc);
    
    shared actual void newModuleProposal(Integer offset, String prefix, Integer len, String versioned,
        ModuleSearchResult.ModuleDetails mod, Boolean withBody, ModuleVersionDetails version, String name,
        Node node, CompletionContext ctx)
            => Result("newModuleProposal", versioned, name);
    
    shared actual void newInvocationCompletion(CompletionContext ctx, Integer offset, String prefix,
        String desc, String text, Declaration dec, Reference? pr, Scope scope,
        Boolean includeDefaulted, Boolean positionalInvocation, Boolean namedInvocation, 
        Boolean inheritance, Boolean qualified, Declaration? qualifyingDec)
    //        => let (name = if (namedInvocation) then "newNamedInvocationCompletion"
    //        else if (positionalInvocation) then "newPositionalInvocationCompletion"
    //    else "newReferenceCompletion"
    //)
    //Result(name, text, desc); 
    {}
    
    shared actual void newPackageDescriptorProposal(CompletionContext ctx, Integer offset, String prefix, String desc, String text)
            => Result("newPackageDescriptorProposal", text, desc);
    
    //suppressWarnings("expressionTypeNothing")
    shared actual void newParameterInfo(CompletionContext ctx, Integer offset, Declaration dec, Reference producedReference, Scope scope,
        Boolean namedInvocation)
    {}
      //      => nothing; // not supported
    
    shared actual void newParametersCompletionProposal(CompletionContext ctx, Integer offset, String prefix, String desc, String text,
        JList<Type> argTypes, Node node, Unit unit)
            => Result("newParametersCompletionProposal", text, desc);
    
    shared actual void newQueriedModulePackageProposal(Integer offset, String prefix, String memberPackageSubname,
        Boolean withBody, String fullPackageName, CompletionContext ctx, ModuleVersionDetails version, Unit unit,
        ModuleSearchResult.ModuleDetails md)
            => Result("newQueriedModulePackageProposal", memberPackageSubname);
    
    shared actual void newRefinementCompletionProposal(Integer offset, String prefix, Reference? pr,
        String desc, String text, CompletionContext ctx, Declaration dec, Scope scope,
        Boolean fullType, Boolean explicitReturnType)
            => Result("newRefinementCompletionProposal", text, desc);
    
    shared actual void newTypeProposal(ProposalsHolder data, Integer offset, Type? type, String text, String desc, Tree.CompilationUnit rootNode)
            => Result("newTypeProposal", text, desc);
    
    shared actual ProposalsHolder createProposalsHolder() => MyProposalsHolder();
    
    shared actual void addNestedProposal(ProposalsHolder proposals, Icons|Declaration icon,
        String description, DefaultRegion region, String text) {}
    shared actual void addProposal(CompletionContext ctx, Integer offset, String prefix, Icons|Declaration icon, String description, String text, ProposalKind kind, TextChange? additionalChange, DefaultRegion? selection) {}
    
    
    
}