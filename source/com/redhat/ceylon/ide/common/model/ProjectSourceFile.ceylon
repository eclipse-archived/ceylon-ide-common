import com.redhat.ceylon.compiler.java.loader {
    UnknownTypeCollector
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.model.delta {
    CompilationUnitDelta,
    DeltaBuilderFactory
}
import com.redhat.ceylon.ide.common.model.parsing {
    CeylonSourceParser
}
import com.redhat.ceylon.ide.common.platform {
    VfsServicesConsumer
}
import com.redhat.ceylon.ide.common.typechecker {
    ProjectPhasedUnit,
    TypecheckerAliases
}
import com.redhat.ceylon.ide.common.util {
    SingleSourceUnitPackage
}
import com.redhat.ceylon.ide.common.vfs {
    VfsAliases,
    BaseFileVirtualFile
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Package
}

import java.lang {
    Error,
    Types
}
import java.lang.ref {
    WeakReference
}
import java.util {
    JList=List
}

import org.antlr.runtime {
    CommonToken
}

shared DeltaBuilderFactory deltaBuilderFactory = DeltaBuilderFactory();

shared alias AnyProjectSourceFile
        => ProjectSourceFile<out Anything, out Anything, out Anything, out Anything>;

shared class ProjectSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>
        (ProjectPhasedUnit<NativeProject,NativeResource,NativeFolder,NativeFile> projectPhasedUnit)
        extends ModifiableSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>
                (projectPhasedUnit)
        satisfies VfsServicesConsumer<NativeProject, NativeResource, NativeFolder, NativeFile>
                & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
                & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
                & VfsAliases<NativeProject,NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    
    value projectPhasedUnitRef = WeakReference(projectPhasedUnit);
    
    shared actual ProjectPhasedUnitAlias? phasedUnit 
            => projectPhasedUnitRef.get();

    resourceFile => phasedUnit?.resourceFile;
    resourceProject => phasedUnit?.resourceProject; 
    resourceRootFolder => phasedUnit?.resourceRootFolder;
    
    shared CompilationUnitDelta? buildDeltaAgainstModel() {
        try {
            value resourceFile = this.resourceFile;
            value resourceRootFolder = this.resourceRootFolder;
            value phasedUnit = this.phasedUnit;
            if (!exists resourceFile) {
                return null;
            }
            if (!exists resourceRootFolder) {
                return null;
            }
            if (!exists phasedUnit) {
                return null;
            }
            value virtualSrcFile 
                    = vfsServices.createVirtualFile(resourceFile, 
                            phasedUnit.ceylonProject.ideArtifact);
            value virtualSrcDir 
                    = vfsServices.createVirtualFolder(resourceRootFolder, 
                            phasedUnit.ceylonProject.ideArtifact);
            value currentTypechecker = phasedUnit.typeChecker;
            if (! exists currentTypechecker) {
                return null;
            }
            value currentModuleManager 
                    = currentTypechecker.phasedUnits.moduleManager;
            value currentModuleSourceMapper 
                    = currentTypechecker.phasedUnits.moduleSourceMapper;
            value singleSourceUnitPackage 
                    = SingleSourceUnitPackage(\ipackage, 
                        virtualSrcFile.path);
            value lastPhasedUnit 
                    = object satisfies CeylonSourceParser<PhasedUnit> {
                
                charset(BaseFileVirtualFile file) 
                        => virtualSrcFile.charset 
                        else phasedUnit.ceylonProject.defaultCharset;
                
                createPhasedUnit(Tree.CompilationUnit cu, 
                                 Package pkg, 
                                 JList<CommonToken> theTokens) 
                        => object extends PhasedUnit(virtualSrcFile, 
                            virtualSrcDir, cu, pkg, 
                            currentModuleManager, 
                            currentModuleSourceMapper,
                            currentTypechecker.context,
                            theTokens) {
                    isAllowedToChangeModel(Declaration declaration) 
                            => !isCentralModelDeclaration(declaration);
                };
            }.parseFileToPhasedUnit(
                currentModuleManager, 
                currentTypechecker, 
                virtualSrcFile, 
                virtualSrcDir, 
                singleSourceUnitPackage);
            
            lastPhasedUnit.validateTree();
            lastPhasedUnit.visitSrcModulePhase();
            lastPhasedUnit.visitRemainingModulePhase();
            lastPhasedUnit.scanDeclarations();
            lastPhasedUnit.scanTypeDeclarations(cancelDidYouMeanSearch);
            lastPhasedUnit.validateRefinement();
            lastPhasedUnit.analyseTypes(cancelDidYouMeanSearch);
            lastPhasedUnit.analyseFlow();
            UnknownTypeCollector utc = UnknownTypeCollector();
            lastPhasedUnit.compilationUnit.visit(utc);
            
            if (lastPhasedUnit.compilationUnit.errors.empty) {
                return deltaBuilderFactory.buildDeltas(
                        phasedUnit, lastPhasedUnit);
            }
            
        } catch(Exception e) {
        } catch(AssertionError e) {
            e.printStackTrace();
        } catch(Error e) {
            if (Types.classForInstance(e).name ==
                "com.redhat.ceylon.compiler.java.runtime.metamodel.ModelError") {
                e.printStackTrace();
            } else {
                throw e;
            }
        }
        
        return null;
    }
}
 
