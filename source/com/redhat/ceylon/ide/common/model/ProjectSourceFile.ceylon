 import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.ide.common.typechecker {
    ProjectPhasedUnit,
    TypecheckerAliases
}
import com.redhat.ceylon.ide.common.model.delta {
    CompilationUnitDelta,
    DeltaBuilderFactory
}
import com.redhat.ceylon.ide.common.vfs {
    VfsAliases,
    BaseFileVirtualFile
}
import com.redhat.ceylon.ide.common.util {
    SingleSourceUnitPackage,
    CeylonSourceParser
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Package
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import org.antlr.runtime {
    CommonToken
}
import com.redhat.ceylon.compiler.java.loader {
    UnknownTypeCollector
}
import java.util {
    JList = List
}
import java.lang {
    Error
}
import ceylon.interop.java {
    javaClassFromInstance
}

DeltaBuilderFactory deltaBuilderFactory = DeltaBuilderFactory();

shared class ProjectSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>(
    ProjectPhasedUnit<NativeProject,NativeResource,NativeFolder,NativeFile> thePhasedUnit)
        extends ModifiableSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>(thePhasedUnit)
        satisfies ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & VfsAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {

    shared actual ProjectPhasedUnitAlias phasedUnit {
        assert(is ProjectPhasedUnitAlias cppu =
            super.phasedUnit);
        return cppu;
    }

    shared actual NativeFile? resourceFile => 
            phasedUnit.resourceFile;
    
    shared actual NativeProject? resourceProject => 
            phasedUnit.resourceProject; 
    
    shared actual NativeFolder? resourceRootFolder =>
            phasedUnit.resourceRootFolder;
    
    shared CompilationUnitDelta? buildDeltaAgainstModel() {
        try {
            value modelPhasedUnit  = phasedUnit;
            
            value vfs = modelPhasedUnit.ceylonProject.model.vfs;
            value virtualSrcFile = vfs.createVirtualFile(modelPhasedUnit.resourceFile);
            value virtualSrcDir = vfs.createVirtualFolder(modelPhasedUnit.resourceRootFolder);
            value currentTypechecker = modelPhasedUnit.typeChecker;
            if (! exists currentTypechecker) {
                return null;
            }
            value currentModuleManager = currentTypechecker.phasedUnits.moduleManager;
            value currentModuleSourceMapper = currentTypechecker.phasedUnits.moduleSourceMapper;
            value singleSourceUnitPackage = SingleSourceUnitPackage(\ipackage, virtualSrcFile.path);
            PhasedUnit? lastPhasedUnit = object satisfies CeylonSourceParser<PhasedUnit> {
                
                shared actual String charset(BaseFileVirtualFile file) =>
                        virtualSrcFile.charset else modelPhasedUnit.ceylonProject.defaultCharset;
                
                shared actual PhasedUnit createPhasedUnit(Tree.CompilationUnit cu, Package pkg, JList<CommonToken> theTokens) =>
                    object extends PhasedUnit(virtualSrcFile, 
                        virtualSrcDir, cu, pkg, 
                        currentModuleManager, 
                        currentModuleSourceMapper,
                        currentTypechecker.context,
                        theTokens) {
                        shared actual Boolean isAllowedToChangeModel(Declaration declaration) =>
                                ! isCentralModelDeclaration(declaration);
                    };
            }.parseFileToPhasedUnit(
                currentModuleManager, 
                currentTypechecker, 
                virtualSrcFile, 
                virtualSrcDir, 
                singleSourceUnitPackage);
            
            if (exists lastPhasedUnit) {
                lastPhasedUnit.validateTree();
                lastPhasedUnit.visitSrcModulePhase();
                lastPhasedUnit.visitRemainingModulePhase();
                lastPhasedUnit.scanDeclarations();
                lastPhasedUnit.scanTypeDeclarations();
                lastPhasedUnit.validateRefinement();
                lastPhasedUnit.analyseTypes();
                lastPhasedUnit.analyseFlow();
                UnknownTypeCollector utc = UnknownTypeCollector();
                lastPhasedUnit.compilationUnit.visit(utc);
                
                if (lastPhasedUnit.compilationUnit.errors.empty) {
                    return deltaBuilderFactory.buildDeltas(modelPhasedUnit, lastPhasedUnit);
                }
            }
        } catch(Exception e) {
        } catch(AssertionError e) {
            e.printStackTrace();
        } catch(Error e) {
            if (javaClassFromInstance(e).name == "com.redhat.ceylon.compiler.java.runtime.metamodel.ModelError") {
                e.printStackTrace();
            } else {
                throw e;
            }
        }
        
        return null;
    }
}
 
