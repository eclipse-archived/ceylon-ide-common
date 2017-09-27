import org.eclipse.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}


"The result of the local typechecking of a CompilationUnit.
 For example, this can be used when a file is being modified,
 but the resulting PhasedUnit should not be added to the global model."
shared interface LocalAnalysisResult satisfies AnalysisResult {

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
    shared default Tree.CompilationUnit? lastCompilationUnit =>
            lastPhasedUnit?.compilationUnit;
}