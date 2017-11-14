/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.model.typechecker.model {
    Declaration
}
import org.eclipse.ceylon.ide.common.model {
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
