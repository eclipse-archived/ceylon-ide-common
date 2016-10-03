import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration
}
import com.redhat.ceylon.ide.common.model {
    cancelDidYouMeanSearch
}

shared class SourceDeclarationHolder {
    shared PhasedUnit phasedUnit;
    shared Tree.Declaration astDeclaration;
    shared variable Boolean isSourceToCompile = true;
    
    variable Declaration? _modelDeclaration = null;
    
    shared new (PhasedUnit phasedUnit, Tree.Declaration astDeclaration, Boolean isSourceToCompile) {
        this.phasedUnit = phasedUnit;
        this.astDeclaration = astDeclaration;
        this.isSourceToCompile = isSourceToCompile;
    }
    
    shared Declaration? modelDeclaration {
        if (_modelDeclaration exists) {
            return _modelDeclaration;
        }
        
        if (isSourceToCompile) {
            _modelDeclaration = astDeclaration.declarationModel;
        }
        
        if (phasedUnit.scanningDeclarations) {
            return null;
        }
        
        if (!phasedUnit.declarationsScanned) {
            phasedUnit.scanDeclarations();
        }
        
        if (!phasedUnit.typeDeclarationsScanned) {
            phasedUnit.scanTypeDeclarations(cancelDidYouMeanSearch);
        }
        
        _modelDeclaration = astDeclaration.declarationModel;
        return _modelDeclaration;
    }
}
