import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Unit
}

import com.redhat.ceylon.ide.common.util {
    SingleSourceUnitPackage
}

shared Boolean isCentralModelDeclaration(Declaration? declaration) => 
        if (exists declaration) 
        then isCentralModelUnit(declaration.unit)
        else true;

shared Boolean isCentralModelUnit(Unit? unit) => 
        if (is CeylonUnit unit) 
        then 
            if (unit is ProjectSourceFile<out Object, out Object, out Object, out Object>) 
            then true 
            else ! (unit.\ipackage is SingleSourceUnitPackage)
        else true;
