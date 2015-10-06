import com.redhat.ceylon.ide.common.util {
    synchronize
}
import java.util {
    WeakHashMap,
    JList=List
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnits,
    TypecheckerUnit
}
import com.redhat.ceylon.ide.common.model {
    IdeModule,
    CeylonProject,
    ProjectSourceFile,
    BaseIdeModule
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    ModuleSourceMapper { ModuleDependencyAnalysisError }
}
import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}
import com.redhat.ceylon.ide.common.vfs {
    FolderVirtualFile,
    FileVirtualFile
}
import com.redhat.ceylon.model.typechecker.util {
    ModuleManager
}
import java.lang.ref {
    WeakReference
}
import ceylon.interop.java {
    CeylonIterable
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor,
    Node
}
import org.antlr.runtime {
    CommonToken
}

shared class ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>
        extends ModifiablePhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    value theWorkingCopies = WeakHashMap<EditedPhasedUnit<NativeResource, NativeFolder, NativeFile>, String>();
    WeakReference<CeylonProject<NativeProject>> ceylonProjectRef;

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
        extends ModifiablePhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>(unitFile, srcDir, cu, p, moduleManager, moduleSourceMapper, typeChecker, tokenStream) {
        ceylonProjectRef = WeakReference(project);
    }

    shared new clone(ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile> other)
            extends ModifiablePhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>.clone(other) {
        ceylonProjectRef = WeakReference(other.ceylonProjectRef.get());
    }

    shared CeylonProject<NativeProject> ceylonProject => 
            ceylonProjectRef.get();

    shared actual TypecheckerUnit newUnit() => 
            ProjectSourceFile(this);

    shared actual NativeFile resourceFile => 
            unitFile.nativeResource;
    
    shared actual NativeProject resourceProject => 
            ceylonProject.ideArtifact;
    
    shared actual NativeFolder resourceRootFolder => 
            srcDir.nativeResource;

    shared actual ProjectSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile> unit { 
        assert(is ProjectSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile> psf=super.unit);
        return psf; 
    }
    
    shared void addWorkingCopy(EditedPhasedUnit<NativeResource, NativeFolder, NativeFile> workingCopy) {
        synchronize {
             on = theWorkingCopies;
             void do() {
                 String? fullPath = workingCopy.unit?.fullPath;
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

                value newCompilationUnit = compilationUnit;
                object extends Visitor() {
                    shared actual void visitAny(Node node) {
                        super.visitAny(node);
                        for (error in CeylonIterable(node.errors)) {
                            if (is ModuleDependencyAnalysisError error) {
                                newCompilationUnit.addError(error);
                            }
                        }
                    }
                }.visit(oldPhasedUnit.compilationUnit);

                oldPhasedUnit.remove();

                // pour les ICrossProjectReference, le but c'est d'enlever ce qu'il y avait (binaires ou source)
                // Ensuite pour les éléments nouveaux , dans le cas binaire il seront normalement trouvés si le
                // classpath est normalement remis à jour, et pour les éléments source, on parcourt tous les projets
                //
            }

            phasedUnits.addPhasedUnit(unitFile, this);
            assert(is BaseIdeModule ideModule = \ipackage.\imodule);
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
            assert (is BaseIdeModule ideModule = \ipackage.\imodule);
            for (moduleInReferencingProject in ideModule.moduleInReferencingProjects) {
                moduleInReferencingProject.removedOriginalUnit(pathRelativeToSrcDir);
            }
        }
    }
}