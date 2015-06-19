import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.model.typechecker.util {
    ModuleManager
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit,
    PhasedUnits,
    TypecheckerUnit
}
import com.redhat.ceylon.model.typechecker.model {
    Package,
    Unit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.vfs {
    FolderVirtualFile,
    FileVirtualFile
}

import java.lang.ref {
    WeakReference
}
import java.util {
    JList=List,
    WeakHashMap
}

import org.antlr.runtime {
    CommonToken
}
import com.redhat.ceylon.ide.common.util {
    synchronize
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    ModuleSourceMapper
}
import com.redhat.ceylon.ide.common.model {
    CeylonProject
}
import com.redhat.ceylon.ide.common {
    IdeModule
}

shared abstract class IdePhasedUnit<NativeResource, NativeFolder, NativeFile> 
        extends PhasedUnit 
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    
    variable WeakReference<TypeChecker>? typeCheckerRef = null;
    
    shared new(
        FileVirtualFile<NativeResource, NativeFolder, NativeFile> unitFile, 
        FolderVirtualFile<NativeResource, NativeFolder, NativeFile> srcDir,
        Tree.CompilationUnit cu, 
        Package p, 
        ModuleManager moduleManager,
        ModuleSourceMapper moduleSourceMapper,
        TypeChecker typeChecker, 
        JList<CommonToken> tokenStream) extends PhasedUnit(unitFile, srcDir, cu, p, moduleManager, moduleSourceMapper, typeChecker.context, tokenStream) {
        typeCheckerRef = WeakReference<TypeChecker>(typeChecker);
    }
    
    shared new Clone(PhasedUnit other) extends PhasedUnit(other) {
        if (is IdePhasedUnit<NativeResource, NativeFolder, NativeFile> other) {
            typeCheckerRef = WeakReference<TypeChecker>(other.typeChecker);
        }
    }
    
    shared actual FileVirtualFile<NativeResource, NativeFolder, NativeFile> unitFile {
        assert(is FileVirtualFile<NativeResource, NativeFolder, NativeFile> theUnitFile = super.unitFile);
        return theUnitFile;
    }

    shared actual FolderVirtualFile<NativeResource, NativeFolder, NativeFile> srcDir {
        assert(is FolderVirtualFile<NativeResource, NativeFolder, NativeFile> theSrcDir = super.srcDir);
        return theSrcDir;
    }
    
    shared TypeChecker? typeChecker {
        return typeCheckerRef?.get();
    }
    
    shared actual default TypecheckerUnit createUnit() {
        Unit? oldUnit = unit;
        value theNewUnit = newUnit();
        if (exists oldUnit) {
            theNewUnit.filename = oldUnit.filename;
            theNewUnit.fullPath = oldUnit.fullPath;
            theNewUnit.relativePath = oldUnit.relativePath;
            theNewUnit.\ipackage = oldUnit.\ipackage;
            theNewUnit.dependentsOf.addAll(oldUnit.dependentsOf);
        }
        return theNewUnit;
    }
    
    
    shared formal TypecheckerUnit newUnit();
}

"Provisional version of the class, in order to be able to compile ModulesScanner"
// TODO Finish the class
shared class EditedPhasedUnit<NativeResource, NativeFolder, NativeFile>(
    FileVirtualFile<NativeResource, NativeFolder, NativeFile> unitFile, 
    FolderVirtualFile<NativeResource, NativeFolder, NativeFile> srcDir,
    Tree.CompilationUnit cu, 
    Package p, 
    ModuleManager moduleManager,
    ModuleSourceMapper moduleSourceMapper,
    TypeChecker typeChecker, 
    JList<CommonToken> tokens) 
        extends IdePhasedUnit<NativeResource, NativeFolder, NativeFile>(
        unitFile,
        srcDir,
        cu,
        p,
        moduleManager,
        moduleSourceMapper,
        typeChecker,
        tokens)
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
    shared actual TypecheckerUnit newUnit() => nothing;
}

class ProjectSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>(
    ProjectPhasedUnit<NativeProject,NativeResource,NativeFolder,NativeFile> projectPhasedUnit) 
        extends TypecheckerUnit()
        given NativeProject satisfies Object
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource 
        given NativeFile satisfies NativeResource {
}

shared class ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile> 
        extends IdePhasedUnit<NativeResource, NativeFolder, NativeFile> 
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    value theWorkingCopies = WeakHashMap<EditedPhasedUnit<NativeResource, NativeFolder, NativeFile>, String>();
    WeakReference<CeylonProject<NativeProject>> ceylonProject;
    
    shared new(
        CeylonProject<NativeProject> project,
        FileVirtualFile<NativeResource, NativeFolder, NativeFile> unitFile, 
        FolderVirtualFile<NativeResource, NativeFolder, NativeFile> srcDir,
        Tree.CompilationUnit cu, 
        Package p, 
        ModuleManager moduleManager,
        ModuleSourceMapper moduleSourceMapper,
        TypeChecker typeChecker, 
        JList<CommonToken> tokenStream)
        extends IdePhasedUnit<NativeResource, NativeFolder, NativeFile>(unitFile, srcDir, cu, p, moduleManager, moduleSourceMapper, typeChecker, tokenStream) {
        ceylonProject = WeakReference(project);
    }
    
    shared new Clone(ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile> other) 
            extends IdePhasedUnit<NativeResource, NativeFolder, NativeFile>.Clone(other) {
        ceylonProject = WeakReference(other.ceylonProject.get());
    }
    
    shared FileVirtualFile<NativeResource, NativeFolder, NativeFile> sourceFile
        => super.unitFile;
    
    shared CeylonProject<NativeProject> sourceProject 
        => ceylonProject.get();
    
    shared actual TypecheckerUnit newUnit() 
        => ProjectSourceFile(this);
    
    shared void addWorkingCopy(EditedPhasedUnit<NativeResource, NativeFolder, NativeFile> workingCopy) {
        synchronize {
             on = theWorkingCopies;
             void do() {
                 String? fullPath = workingCopy.unit.fullPath; // TODO : check if unit might be null (then refine IdePhasedUnit.unit
                 if (exists fullPath) {
                     value itr = theWorkingCopies.values().iterator();
                     while (itr.hasNext()) {
                         if (itr.next().equals(fullPath)) {
                             itr.remove();
                         }
                     }
                     theWorkingCopies.put(workingCopy, fullPath);
                 }
             }
        };
    }
    
    shared {EditedPhasedUnit<NativeResource, NativeFolder, NativeFile>*} workingCopies {
        return CeylonIterable(theWorkingCopies.keySet());
    }
    
    shared void install() {
        if (exists tc = typeChecker) {
            PhasedUnits phasedUnits = tc.phasedUnits;
            if (is ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile> oldPhasedUnit = phasedUnits.getPhasedUnitFromRelativePath(pathRelativeToSrcDir)) {
                if (oldPhasedUnit === this) {
                    return; // Nothing to do : the PhasedUnit is already installed in the typechecker
                }
                unit.dependentsOf.addAll(oldPhasedUnit.unit.dependentsOf);
                oldPhasedUnit.workingCopies.each((copy) => addWorkingCopy(copy)); 
                oldPhasedUnit.remove();
                
                // pour les ICrossProjectReference, le but c'est d'enlever ce qu'il y avait (binaires ou source) 
                // Ensuite pour les éléments nouveaux , dans le cas binaire il seront normalement trouvés si le 
                // classpath est normalement remis à jour, et pour les éléments source, on parcourt tous les projets
                // 
            }
            
            phasedUnits.addPhasedUnit(unitFile, this);
            assert(is IdeModule ideModule = \ipackage.\imodule);
            for (moduleInReferencingProject in ideModule.moduleInReferencingProjects) {
                moduleInReferencingProject.addedOriginalUnit(pathRelativeToSrcDir);
            }
            
            // Pour tous les projets dépendants, on appelle addPhasedUnit () sur le module correspondant, qui doit être un module source externe
            // Attention : penser à ajouter une étape de retypecheck des modules dépendants à la compil incrémentale. De toute manière ceux qui sont déjà faits ne seront pas refaits.  
        }
    }
    
    shared void remove() {
        if (exists tc = typeChecker) {
            PhasedUnits phasedUnits = tc.phasedUnits;
            phasedUnits.removePhasedUnitForRelativePath(pathRelativeToSrcDir); // remove also the ProjectSourceFile (unit) from the Package
            assert (is IdeModule ideModule = \ipackage.\imodule);
            for (moduleInReferencingProject in ideModule.moduleInReferencingProjects) {
                moduleInReferencingProject.removedOriginalUnit(pathRelativeToSrcDir);
            }
        }
    }
}

