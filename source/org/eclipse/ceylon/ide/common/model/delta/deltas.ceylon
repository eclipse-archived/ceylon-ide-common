/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.model.typechecker.model {
    Declaration,
    Unit,
    Module,
    Package,
    ModuleImport
}

import java.lang {
    Types
}

shared alias DifferencedModelElement
        => Module
         | ModuleImport
         | Package
         | Unit
         | Declaration;

shared interface AbstractDelta
        of CompilationUnitDelta
         | ModuleImportDelta
         | DeclarationRelatedDelta {
    "Element for which the delta has been calculated"
    shared formal DifferencedModelElement? changedElement;

    "String representation of the changedElement"
    shared default String changedElementString
            => changedElement?.string else "<unknown>";

    "Deltas related to the members of the  [[model element|AbstractDelta.changedElement]]
     that might impact some other compilation units"
    shared formal {AbstractDelta*} childrenDeltas;

    "Changes on the [[model element|AbstractDelta.changedElement]] that might impact some
     other compilation units"
    shared formal {ImpactingChange*} changes;

    shared actual String string {
        return "`` changedElementString `` {
                  changes = {`` ", ".join(changes) ``}
                  childrenDeltas = {`` ((childrenDeltas.empty) then "}" else "
                  ") + operatingSystem.newline.join {
                          for (childDelta in childrenDeltas)
                          for (line in childDelta.string.lines)
                          "    " + line
                      }
                  + ((! childrenDeltas.empty) then
               "
                  }" else "") ``
                }";
    }
    shared default actual Boolean equals(Object that) {
        if (is AbstractDelta that) {
            return changedElementString == that.changedElementString
                && childrenDeltas.size == that.childrenDeltas.size
                && changes.size == that.changes.size
                && !anyPair(childrenDeltas, that.childrenDeltas,
                        (first, second) => first != second)
                && !anyPair(changes, that.changes,
                        (first, second) => first != second);
        }
        else {
            return false;
        }
    }
}

shared interface CompilationUnitDelta
        of RegularCompilationUnitDelta
         | ModuleDescriptorDelta
         | PackageDescriptorDelta
        satisfies AbstractDelta {}

shared interface ModuleDescriptorDelta satisfies CompilationUnitDelta {
    shared default actual String changedElementString
            => if (exists m=changedElement)
            then "Module[``m.nameAsString``, ``m.version``]"
            else "<unknown>";
    shared formal actual Module? changedElement;
    shared formal actual {ModuleImportDelta*} childrenDeltas;
    shared alias PossibleChange => StructuralChange | ModuleImportAdded;
    shared formal actual {PossibleChange*} changes;
}

shared class InvalidModuleDescriptorDelta() satisfies ModuleDescriptorDelta {
    shared actual Module? changedElement => null;
    shared actual [StructuralChange] changes => [structuralChange];
    shared actual {ModuleImportDelta*} childrenDeltas => {};
    shared actual Boolean equals(Object that) => (super of AbstractDelta).equals(that);
}

shared interface ModuleImportDelta satisfies AbstractDelta {
    shared formal actual ModuleImport? changedElement;
    shared actual [] childrenDeltas => [];
    "StructuralChange when the optiobal annotation has been changed"
    shared alias PossibleChange
            => StructuralChange
             | Removed
             | MadeVisibleOutsideScope
             | MadeInvisibleOutsideScope;
    shared formal actual [PossibleChange]|[] changes;
}

shared interface PackageDescriptorDelta satisfies CompilationUnitDelta {
    shared default actual String changedElementString
            => if (exists p=changedElement)
            then "Package[``p.nameAsString``]"
            else "<unknown>";
    shared formal actual Package? changedElement;
    shared actual [] childrenDeltas => [];
    shared alias PossibleChange
            => StructuralChange
             | MadeVisibleOutsideScope
             | MadeInvisibleOutsideScope;
    shared formal actual [PossibleChange]|[] changes;
}

shared class InvalidPackageDescriptorDelta() satisfies PackageDescriptorDelta {
    shared actual Package? changedElement => null;
    shared actual [StructuralChange] changes => [structuralChange];
    shared actual Boolean equals(Object that) => (super of AbstractDelta).equals(that);
}

shared interface DeclarationRelatedDelta
        of DeclarationDelta
         | SpecifierDelta
        satisfies AbstractDelta {
    shared formal actual Declaration? changedElement;
    shared default actual String changedElementString
            => if (exists declaration=changedElement)
            then "``Types.classForInstance(declaration).simpleName``[``declaration.nameAsString``]"
            else "<unknown>";
}

shared interface DeclarationDelta
        of TopLevelDeclarationDelta
         | NestedDeclarationDelta
        satisfies DeclarationRelatedDelta {
    shared formal actual {NestedDeclarationDelta|SpecifierDelta*} childrenDeltas;
}

shared interface SpecifierDelta satisfies DeclarationRelatedDelta {
    shared alias PossibleChange => StructuralChange | Removed;
    shared formal actual {PossibleChange*} changes;
    shared actual [] childrenDeltas => [];
}

shared interface TopLevelDeclarationDelta satisfies DeclarationDelta {
    shared alias PossibleChange
            => StructuralChange
             | Removed
             | DeclarationMemberAdded
             | MadeVisibleOutsideScope
             | MadeInvisibleOutsideScope;
    shared formal actual {<PossibleChange>*} changes;
}

shared interface NestedDeclarationDelta satisfies DeclarationDelta {
    shared alias PossibleChange
            => StructuralChange
             | Removed
             | DeclarationMemberAdded;
    shared formal actual {PossibleChange*} changes;
}

shared interface RegularCompilationUnitDelta satisfies CompilationUnitDelta {
    shared default actual String changedElementString => "Unit[``changedElement.filename``]";
    shared formal actual Unit changedElement;
    shared alias PossibleChange => TopLevelDeclarationAdded;
    shared formal actual {PossibleChange*} changes;
    shared formal actual {TopLevelDeclarationDelta*} childrenDeltas;
}
