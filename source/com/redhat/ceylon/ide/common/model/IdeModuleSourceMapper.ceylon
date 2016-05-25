import ceylon.interop.java {
    javaString
}

import com.redhat.ceylon.cmr.api {
    ArtifactContext,
    RepositoryManager
}
import com.redhat.ceylon.compiler.java.loader.model {
    LazyModuleSourceMapper
}
import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    ModuleHelper,
    ModuleSourceMapper
}
import com.redhat.ceylon.compiler.typechecker.context {
    Context,
    PhasedUnits
}
import com.redhat.ceylon.compiler.typechecker.io {
    VirtualFile
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.compiler.typechecker.util {
    ModuleManagerFactory
}
import com.redhat.ceylon.ide.common.model.parsing {
    CeylonSourceParser
}
import com.redhat.ceylon.ide.common.typechecker {
    ExternalPhasedUnit,
    CrossProjectPhasedUnit,
    TypecheckerAliases
}
import com.redhat.ceylon.ide.common.util {
    unsafeCast
}
import com.redhat.ceylon.ide.common.vfs {
    ZipFileVirtualFile,
    ZipEntryVirtualFile,
    BaseFileVirtualFile
}
import com.redhat.ceylon.model.cmr {
    ArtifactResult
}
import com.redhat.ceylon.model.typechecker.model {
    Module,
    ModuleImport,
    Package
}
import com.redhat.ceylon.model.typechecker.util {
    ModuleManager
}

import java.io {
    File
}
import java.lang {
    JString=String
}
import java.util {
    List,
    LinkedList,
    ArrayList
}

import org.antlr.runtime {
    CommonToken
}

shared abstract class ExternalModulePhasedUnits(Context context, ModuleManagerFactory moduleManagerFactory) 
        extends PhasedUnits(context, moduleManagerFactory) {
    shared formal void parseFileInPackage(VirtualFile file, VirtualFile srcDir, Package pkg);
}

shared abstract class BaseIdeModuleSourceMapper(Context theContext, BaseIdeModuleManager theModuleManager) 
        extends LazyModuleSourceMapper(theContext, theModuleManager) {
    
    theModuleManager.moduleSourceMapper = this;

    shared actual default BaseIdeModuleManager moduleManager {
        assert(is BaseIdeModuleManager mm=super.moduleManager);
        return mm;
    }

    shared actual Context context =>
            super.context;
    
    shared formal BaseCeylonProject? ceylonProject;
    shared variable late TypeChecker typeChecker;

    shared formal void logModuleResolvingError(BaseIdeModule theModule, Exception e);
    shared formal String defaultCharset;
    
    shared actual void resolveModule(
        variable ArtifactResult artifact, 
        Module theModule, 
        ModuleImport moduleImport, 
        LinkedList<Module> dependencyTree, 
        List<PhasedUnits> phasedUnitsOfDependencies, 
        Boolean forCompiledModule) {
        variable File artifactFile = artifact.artifact();
        if (ceylonProject?.loadInterProjectDependenciesFromSourcesFirst else false,
            moduleManager.searchForOriginalModule(theModule.nameAsString, artifactFile) exists) {
            moduleManager.sourceModules.add(theModule.nameAsString);
        }
        if (moduleManager.isModuleLoadedFromSource(theModule.nameAsString), 
            artifactFile.name.endsWith(ArtifactContext.\iCAR)) {
            value artifactContext = ArtifactContext(theModule.nameAsString, theModule.version, ArtifactContext.\iSRC);
            RepositoryManager repositoryManager = context.repositoryManager;
            variable Exception? exceptionOnGetArtifact = null;
            variable ArtifactResult? sourceArtifact = null;
            try {
                sourceArtifact = repositoryManager.getArtifactResult(artifactContext);
            }
            catch (Exception e) {
                exceptionOnGetArtifact = e;
            }
            if (exists existingSourceArtifact=sourceArtifact) {
                artifact = existingSourceArtifact;
            }
            else {
                ModuleHelper.buildErrorOnMissingArtifact(artifactContext, theModule, moduleImport, dependencyTree, exceptionOnGetArtifact, this);
            }
        }
        if (is BaseIdeModule theModule) {
            (theModule).setArtifactResult(artifact);
        }
        if (!moduleManager.isModuleLoadedFromCompiledSource(theModule.nameAsString)) {
            variable File file = artifact.artifact();
            if (artifact.artifact().name.endsWith(".src")) {
                moduleManager.sourceModules.add(theModule.nameAsString);
                file = File(javaString(file.absolutePath).replaceAll("\\.src$", ".car"));
            }
        }
        try {
            super.resolveModule(artifact, theModule, moduleImport, dependencyTree, phasedUnitsOfDependencies, forCompiledModule);
        }
        catch (Exception e) {
            if (is BaseIdeModule theModule) {
                logModuleResolvingError(theModule, e);
                (theModule).setResolutionException(e);
            }
        }
    }
    
    shared actual void visitModuleFile() {
        value currentPkg = currentPackage;
        moduleManager.sourceModules.add(currentPkg.nameAsString);
        super.visitModuleFile();
    }
    
    shared void addTopLevelModuleError() {
        addErrorToModule(ArrayList<JString>(), "A module cannot be defined at the top level of the hierarchy");
    }
    
    shared actual formal ExternalModulePhasedUnits createPhasedUnits();
    
    shared actual void addToPhasedUnitsOfDependencies(
        PhasedUnits modulePhasedUnits, 
        List<PhasedUnits> phasedUnitsOfDependencies, 
        Module \imodule) {
        super.addToPhasedUnitsOfDependencies(modulePhasedUnits, phasedUnitsOfDependencies, \imodule);
        if (is BaseIdeModule \imodule) {
            assert(is ExternalModulePhasedUnits modulePhasedUnits);
            \imodule.setSourcePhasedUnits(modulePhasedUnits);
        }
    }
    
}

"Provisional version of the class, in order to be able to compile ModulesScanner"
shared abstract class IdeModuleSourceMapper<NativeProject, NativeResource, NativeFolder, NativeFile>(
    Context context, 
    IdeModuleManager<NativeProject, NativeResource, NativeFolder, NativeFile> theModuleManager) 
		extends BaseIdeModuleSourceMapper(context, theModuleManager) 
        satisfies ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {

    shared actual CeylonProjectAlias? ceylonProject => theModuleManager.ceylonProject;
    
	shared actual default IdeModuleManagerAlias moduleManager =>
            unsafeCast<IdeModuleManagerAlias>(super.moduleManager);
	
	value currentSourceMapper => this;
	
	shared actual ExternalModulePhasedUnits createPhasedUnits() {
		ModuleManagerFactory moduleManagerFactory = object satisfies ModuleManagerFactory {
			
			shared actual ModuleManager createModuleManager(variable Context context) {
				return moduleManager;
			}
			
			shared actual ModuleSourceMapper createModuleManagerUtil(variable Context context, variable ModuleManager moduleManager) {
				return currentSourceMapper;
			}
			
		};
		return object extends ExternalModulePhasedUnits(context, moduleManagerFactory) {
			
			variable CeylonProjectAlias? referencedProject = null;
			
			shared actual void parseFile(VirtualFile file, VirtualFile srcDir) {
				if (file.name.endsWith(".ceylon")) {
					parseFileInPackage(file, srcDir, currentSourceMapper.currentPackage);
				}
			}
			
			shared actual void parseFileInPackage(VirtualFile file, VirtualFile srcDir, Package pkg) {
				assert(is ZipEntryVirtualFile zipEntry=file);
				assert(is ZipFileVirtualFile zipArchive=srcDir);
				value sourceParser = object satisfies CeylonSourceParser<ExternalPhasedUnit> {
					
					shared actual ExternalPhasedUnit createPhasedUnit(
						Tree.CompilationUnit cu,
						Package pkg,
						List<CommonToken> tokens) => 
							if (exists rp=referencedProject) 
					then CrossProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>(
							zipEntry, 
							zipArchive, 
							cu, 
							pkg, 
							moduleManager, 
							currentSourceMapper, 
							typeChecker, 
							tokens, 
							rp) 
					else ExternalPhasedUnit(
								zipEntry, 
								zipArchive, 
								cu, 
								pkg, 
								moduleManager, 
								currentSourceMapper, 
								typeChecker, 
								tokens);
					
					shared actual String charset(BaseFileVirtualFile file) => 
							/* TODO: is this correct? does this file actually
							  live in the project, or is it external?
							  should VirtualFile have a getCharset()? */
							ceylonProject?.defaultCharset else defaultCharset;
				};
				value phasedUnit = sourceParser.parseFileToPhasedUnit(moduleManager, typeChecker, zipEntry, zipArchive, pkg);
				addPhasedUnit(file, phasedUnit);
			}
			
			shared actual void parseUnit(variable VirtualFile srcDir) {
				if (srcDir is ZipFileVirtualFile, exists p=ceylonProject) {
					assert(is ZipFileVirtualFile zipFileVirtualFile = srcDir);
					String archiveName = zipFileVirtualFile.path;
					for (refProject in p.referencedCeylonProjects) {
						if (refProject.ceylonModulesOutputDirectory.absolutePath in archiveName) {
							referencedProject = refProject;
							break;
						}
					}
				}
				super.parseUnit(srcDir);
			}
		};
	}
}

