import org.eclipse.ceylon.compiler.typechecker {
    TypeChecker
}
import org.eclipse.ceylon.compiler.typechecker.analyzer {
    ModuleSourceMapper {
        ModuleDependencyAnalysisError
    }
}
import org.eclipse.ceylon.compiler.typechecker.context {
    PhasedUnits,
    TypecheckerUnit
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor,
    Node
}
import org.eclipse.ceylon.ide.common.model {
    BaseIdeModule,
    ModelAliases,
    BaseIdeModuleSourceMapper,
    ProjectSourceFile
}
import org.eclipse.ceylon.ide.common.platform {
    ModelServicesConsumer
}
import org.eclipse.ceylon.ide.common.util {
    synchronize,
    unsafeCast
}
import org.eclipse.ceylon.ide.common.vfs {
    VfsAliases
}
import org.eclipse.ceylon.model.typechecker.model {
    Package
}
import org.eclipse.ceylon.model.typechecker.util {
    ModuleManager
}

import java.lang.ref {
    WeakReference
}
import java.util {
    WeakHashMap,
    JList=List
}

import org.antlr.runtime {
    CommonToken
}

shared alias AnyProjectPhasedUnit => ProjectPhasedUnit<in Nothing, in Nothing, in Nothing, in Nothing>;

shared class ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>
        extends ModifiablePhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>
        satisfies ModelServicesConsumer<NativeProject, NativeResource, NativeFolder, NativeFile>
                & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
                & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
                & VfsAliases<NativeProject,NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    
    value theWorkingCopies = WeakHashMap<EditedPhasedUnitAlias, String>();
    WeakReference<CeylonProjectAlias> ceylonProjectRef;

    shared new(
        CeylonProjectAlias project,
        FileVirtualFileAlias unitFile,
        FolderVirtualFileAlias srcDir,
        Tree.CompilationUnit cu,
        Package p,
        ModuleManager moduleManager,
        BaseIdeModuleSourceMapper moduleSourceMapper,
        TypeChecker typeChecker,
        JList<CommonToken> tokenStream)
        extends ModifiablePhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>
            (unitFile, srcDir, cu, p, moduleManager, moduleSourceMapper, typeChecker, tokenStream) {
        ceylonProjectRef = WeakReference(project);
    }

    shared new clone(ProjectPhasedUnitAlias other)
            extends ModifiablePhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>.clone(other) {
        ceylonProjectRef = WeakReference(other.ceylonProjectRef.get());
    }

    shared CeylonProjectAlias ceylonProject 
            => ceylonProjectRef.get();

    shared actual TypecheckerUnit createUnit() 
            => object satisfies ModelServicesConsumer<NativeProject, NativeResource, NativeFolder, NativeFile>{
            }.modelServices.newProjectSourceFile(this);

    shared actual NativeFile resourceFile => unitFile.nativeResource;
    shared actual NativeProject resourceProject => ceylonProject.ideArtifact;
    shared actual NativeFolder resourceRootFolder => srcDir.nativeResource;

    shared actual ProjectSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile> unit 
            => unsafeCast<ProjectSourceFileAlias>(super.unit);
    
    shared void addWorkingCopy(EditedPhasedUnitAlias workingCopy) {
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
                     theWorkingCopies[workingCopy] = fullPath;
                 }
             }
        };
    }

    shared {EditedPhasedUnitAlias*} workingCopies => { *theWorkingCopies.keySet() };

    shared void install() {
        if (exists tc = typeChecker) {
            PhasedUnits phasedUnits = tc.phasedUnits;
            if (is ProjectPhasedUnit<NativeProject,NativeResource,NativeFolder,NativeFile> oldPhasedUnit 
                    = phasedUnits.getPhasedUnitFromRelativePath(pathRelativeToSrcDir)) {
                if (oldPhasedUnit === this) {
                    return; // Nothing to do : the PhasedUnit is already installed in the typechecker
                }
                unit.dependentsOf.addAll(oldPhasedUnit.unit.dependentsOf);
                oldPhasedUnit.workingCopies.each((copy) => addWorkingCopy(copy));

                value newCompilationUnit = compilationUnit;
                object extends Visitor() {
                    shared actual void visitAny(Node node) {
                        super.visitAny(node);
                        for (error in node.errors) {
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
            assert (is BaseIdeModule ideModule = \ipackage.\imodule);
            for (moduleInReferencingProject in ideModule.moduleInReferencingProjects) {
                moduleInReferencingProject.addedOriginalUnit(pathRelativeToSrcDir);
            }

            // Pour tous les projets dépendants, on appelle addPhasedUnit () sur le module correspondant, qui doit être un module source externe
            // Attention : penser à ajouter une étape de retypecheck des modules dépendants à la compil incrémentale. De toute manière ceux qui sont déjà faits ne seront pas refaits.
        }
    }

    shared void remove() {
        if (exists tc = typeChecker) {
            tc.phasedUnits.removePhasedUnitForRelativePath(pathRelativeToSrcDir); // remove also the ProjectSourceFile (unit) from the Package
            assert (is BaseIdeModule ideModule = \ipackage.\imodule);
            for (moduleInReferencingProject in ideModule.moduleInReferencingProjects) {
                moduleInReferencingProject.removedOriginalUnit(pathRelativeToSrcDir);
            }
        }
    }
}