import java.util {
    Stack
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Package,
    Scope,
    Value
}
import com.redhat.ceylon.ide.common.typechecker {
    ExternalPhasedUnit
}
import com.redhat.ceylon.ide.common.util {
    SingleSourceUnitPackage,
    equalsWithNulls,
    unsafeCast
}
"
 Used when the external declarations come from a source archive
 "
shared class ExternalSourceFile(ExternalPhasedUnit thePhasedUnit) 
        extends SourceFile(thePhasedUnit) {
        
        shared actual default ExternalPhasedUnit phasedUnit =>
                unsafeCast<ExternalPhasedUnit>(super.phasedUnit);
        
        shared Boolean binaryDeclarationSource {
            return ceylonModule.isCeylonBinaryArchive && (ceylonPackage is SingleSourceUnitPackage);
        }
        
        // TODO : check this method !!!
        shared Declaration? retrieveBinaryDeclaration(Declaration sourceDeclaration) {
            if (!equalsWithNulls(this, sourceDeclaration.unit else null)) {
                return null;
            }
            variable Declaration? binaryDeclaration = null;
            if (binaryDeclarationSource) {
                assert(is SingleSourceUnitPackage sourceUnitPackage = \ipackage);
                Package binaryPackage = sourceUnitPackage.modelPackage;
                Stack<Declaration> ancestors = Stack<Declaration>();
                variable Scope container = sourceDeclaration.container;
                while (container is Declaration) {
                    assert(is Declaration ancestor = container);
                    ancestors.push(ancestor);
                    container = (ancestor of Declaration).container;
                }
                if (container.equals(sourceUnitPackage)) {
                    variable Scope? curentBinaryScope = binaryPackage;
                    while (!ancestors.empty()) {
                        variable Declaration? binaryAncestor = curentBinaryScope?.getDirectMember(ancestors.pop().name, null, false);
                        if (is Value valueAncestor=binaryAncestor) {
                            binaryAncestor = valueAncestor.typeDeclaration;
                        }
                        if (is Scope scopeAncestor=binaryAncestor) {
                            curentBinaryScope = scopeAncestor;
                        }
                        else {
                            break;
                        }
                    }
                    if (exists foundBinaryScope=curentBinaryScope) {
                        binaryDeclaration = foundBinaryScope.getDirectMember(sourceDeclaration.name, null, false);
                    }
                }
            }
            return binaryDeclaration;
        }
    }
