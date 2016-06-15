import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.model {
    BaseCeylonProject
}
import com.redhat.ceylon.ide.common.platform {
    CommonDocument
}

import java.util {
    List
}

import org.antlr.runtime {
    CommonToken
}


"The result of the local typechecking of a CompilationUnit.
 For example, this can be used when a file is being modified,
 but the resulting PhasedUnit should not be added to the global model."
shared interface LocalAnalysisResult {

    "The document of the most-recently parsed AST"
    shared formal CommonDocument commonDocument;
    
    "The token stream of the most-recently parsed AST"
    shared formal List<CommonToken> tokens;
    
    "Most recently parsed AST.
     
     __Be careful__ it can be returned *before* the typechecking or
     *during* the typechecking (in case of cancellation).
     So *never* use this from places that need a fully typechecked AST
     (with model elements such as declarations or units)."
    shared formal Tree.CompilationUnit parsedRootNode;
    

    "The last typechecked [[PhasedUnit]].
     
     The associated AST might be different from the most 
     recently parsed AST,
     and thus inconsistent with the source code.
     
     It can be [[null]] if not typechecking ever occured
     on this document."
    shared formal PhasedUnit? lastPhasedUnit;
    
    "The last fully-typechecked AST.
     It might be different from the most recently parsed AST,
     and thus inconsistent with the source code
     
     It can be [[null]] if not typechecking ever occured
     on this document."
    shared formal Tree.CompilationUnit? lastCompilationUnit;

    "The typechecker used during the last typecheck.
     Can be [[null]] if no typechecking was performed"
    shared formal TypeChecker? typeChecker;
    
    "Returns the last parsed AST only if it is fully typechecked,
     or [[null]] if the last parsed AST could not be fully
     typechecked
     (cancellation, source model read lock not obtained,
     running typechecking ...)"
    shared formal Tree.CompilationUnit? typecheckedRootNode;
    
    "The [[BaseCeylonProject]] of this document.
     Can be [[null]] for non-physical documents
     such as VCS document version, 
     comparison editor documents, etc..."
    shared formal BaseCeylonProject? ceylonProject;
    
    shared Boolean upToDate => typecheckedRootNode exists;
}