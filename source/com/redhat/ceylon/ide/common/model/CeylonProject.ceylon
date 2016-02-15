import com.redhat.ceylon.cmr.api {
    RepositoryManager,
    Overrides
}
import com.redhat.ceylon.cmr.ceylon {
    CeylonUtils {
        CeylonRepoManagerBuilder
    }
}
import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnits
}
import com.redhat.ceylon.ide.common.util {
    Path,
    unsafeCast,
    platformUtils,
    toJavaStringList
}
import com.redhat.ceylon.ide.common.vfs {
    FolderVirtualFile,
    BaseFolderVirtualFile
}
import com.redhat.ceylon.model.typechecker.model {
    TypecheckerModules=Modules,
    Package
}

import java.io {
    File
}
import java.lang {
    InterruptedException,
    RuntimeException,
    IllegalStateException
}
import java.lang.ref {
    WeakReference
}
import java.util.concurrent {
    TimeUnit
}
import java.util.concurrent.locks {
    ReentrantReadWriteLock,
    ReadWriteLock,
    Lock,
    ReentrantLock
}

import org.xml.sax {
    SAXParseException
}

shared abstract class BaseCeylonProject() {
    shared String ceylonConfigFileProjectRelativePath = ".ceylon/config";
    variable CeylonProjectConfig? ceylonConfig = null;
    variable CeylonIdeConfig? ideConfig = null;
    shared ReadWriteLock sourceModelLock =  ReentrantReadWriteLock();
    Lock repositoryManagerLock = ReentrantLock();
    variable RepositoryManager? _repositoryManager = null;
    
    shared formal BaseCeylonProjects model;
    shared formal String name;
    shared formal File rootDirectory;
    shared formal Boolean hasConfigFile;
    shared formal String systemRepository;
    shared formal void createOverridesProblemMarker(
        Exception theOverridesException, 
        File absoluteFile, 
        Integer overridesLine, 
        Integer overridesColumn);
    shared formal void removeOverridesProblemMarker();

    function createRepositoryManager() {
        return object extends CeylonRepoManagerBuilder() {
            shared actual Overrides? getOverrides(String? path) {
                if (! path exists) {
                    removeOverridesProblemMarker();
                }
                return super.getOverrides(path);
            }
            
            shared actual Overrides? getOverrides(File absoluteFile) {
                variable Overrides? result = null;
                variable Exception? overridesException = null;
                variable Integer overridesLine = -1;
                variable Integer overridesColumn = -1;
                try {
                    result = super.getOverrides(absoluteFile);
                } catch(Overrides.InvalidOverrideException e) {
                    overridesException = e;
                    overridesLine = e.line;
                    overridesColumn = e.column;
                } catch(IllegalStateException e) {
                    Throwable? cause = e.cause;
                    if (is SAXParseException cause) {
                        value parseException =  cause;
                        overridesException = parseException;
                        overridesLine = parseException.lineNumber;
                        overridesColumn = parseException.columnNumber;
                    } else if (is Exception cause) {
                        overridesException = cause;
                    } else {
                        overridesException = e;
                    }
                } catch(Exception e) {
                    overridesException = e;
                }
                
                if (exists theOverridesException = overridesException) {
                    createOverridesProblemMarker(
                        theOverridesException, 
                        absoluteFile, 
                        overridesLine, 
                        overridesColumn);
                } else {
                    removeOverridesProblemMarker();
                }
                return result;
            }
        }.offline(configuration.offline)
                .cwd(rootDirectory)
                .systemRepo(systemRepository)
                .extraUserRepos(
                    toJavaStringList(
                        referencedCeylonProjects.map((p) 
                            => p.ceylonModulesOutputDirectory.absolutePath)))
                .logger(platformUtils.cmrLogger)
                .isJDKIncluded(true)
                .buildManager();
    }
    
    shared RepositoryManager repositoryManager {
        try {
            repositoryManagerLock.lock();
            if (exists theRepoManager=_repositoryManager) {
                return theRepoManager;
            } else {
                value newRepoManager = createRepositoryManager();
                _repositoryManager = newRepoManager;
                return newRepoManager;
            }
        } finally {
            repositoryManagerLock.unlock();
        }
        
    }

    shared void resetRepositoryManager() {
        try {
            repositoryManagerLock.lock();
            _repositoryManager = null;
        } finally {
            repositoryManagerLock.unlock();
        }
        
    }

    deprecated("Only here for compatibility with legacy code
                This should be removed, since the real entry point is the [[PhasedUnits]] object
                
                The only interesting data contained in the [[TypeChecker]] is the
                [[phasedUnitsOfDependencies|TypeChecker.phasedUnitsOfDependencies]]. But new they
                should be managed in a modular way in each [[IdeModule]] object accessible from the
                [[PhasedUnits]]")
    shared formal TypeChecker? typechecker;
    
    deprecated("Should be hidden in the future, when implemented directy here in Ceylon")
    shared default PhasedUnits? phasedUnits=>typechecker?.phasedUnits;
    
    shared CeylonProjectConfig configuration {
        if (exists config = ceylonConfig) {
            return config;
        } else {
            value newConfig = CeylonProjectConfig(this);
            ceylonConfig = newConfig;
            return newConfig;
        }
    }

    shared CeylonIdeConfig ideConfiguration {
        if (exists config = ideConfig) {
            return config;
        } else {
            value newConfig = CeylonIdeConfig(this);
            ideConfig = newConfig;
            return newConfig;
        }
    }
    
    
    shared String defaultCharset
            => configuration.encoding else defaultDefaultCharset;
    
    shared default String defaultDefaultCharset
            => "utf8";
    
    "Un-hide a previously hidden output folder in old Eclipse projects
     For other IDEs, do nothing"
    shared default void fixHiddenOutputFolder(String folderProjectRelativePath) => noop();
    shared formal void deleteOldOutputFolder(String folderProjectRelativePath);
    shared formal void createNewOutputFolder(String folderProjectRelativePath);
    shared formal void refreshConfigFile();
    
    shared formal Boolean synchronizedWithConfiguration;
    shared formal Boolean nativeProjectIsAccessible;
    shared formal Boolean compileToJs;
    shared formal Boolean compileToJava;

    value loadBinariesFirst => 
            "true".equals(process.propertyValue("ceylon.loadBinariesFirst") else "true");
    
    shared Boolean loadDependenciesFromModelLoaderFirst =>
            compileToJava && loadBinariesFirst;
    
    shared {String*} ceylonRepositories
            => let (c = configuration) c.projectLocalRepos
            .chain(c.globalLookupRepos)
            .chain(c.projectRemoteRepos)
            .chain(c.otherRemoteRepos);

    shared default Boolean isJavaLikeFileName(String fileName) =>
            fileName.endsWith(".java");
    
    shared formal {BaseCeylonProject*} referencedCeylonProjects;
    shared formal {BaseCeylonProject*} referencingCeylonProjects;

    shared File ceylonModulesOutputDirectory =>
            File(
        Path(rootDirectory.absolutePath)
                .append(configuration.outputRepoProjectRelativePath)
                .platformDependentString);
    
    shared formal ModuleDependencies moduleDependencies;

    shared default abstract class Modules() satisfies {BaseIdeModule*} {
        shared formal BaseIdeModule default;
        shared formal BaseIdeModule language;
        shared formal Package? javaLangPackage;        
        shared formal {BaseIdeModule*} fromProject;
        shared formal {BaseIdeModule*} external;
        
        shared formal BaseIdeModuleManager manager;
        shared formal BaseIdeModuleSourceMapper sourceMapper;
    }

    shared formal Modules? modules;
    
    shared formal {BaseFolderVirtualFile*} sourceFolders;
    shared formal {BaseFolderVirtualFile*} resourceFolders;
    
    "
     Allows synchronizing operations that involve the source-related
     Ceylon model, for example:
     - setting up the typechecker,
     - creating or typechecking PhasedUnits,
     - etc ...
     
     It's based on a ReentrantReadWriteLock.

     To avoid deadlock, it always takes a time limit,
     after which the it stops waiting for the source 
     model availability and throws a [[RuntimeException|java.lang::RuntimeException]] Exception.
     The thrown exception is the one produced by 
     [[IdePlatformUtils.newOperationCanceledException|com.redhat.ceylon.ide.common.util::IdePlatformUtils.newOperationCanceledException]]
     "
    shared Return withSourceModel<Return>(Boolean readonly, Return() do, Integer waitForModelInSeconds=20) {
        try {
            value theLock = 
                    if (readonly) 
                    then sourceModelLock.readLock() 
                    else sourceModelLock.writeLock();
            if (theLock.tryLock(waitForModelInSeconds, TimeUnit.\iSECONDS)) {
                try {
                    return do();
                } finally {
                    theLock.unlock();
                }
            } else {
                throw platformUtils.newOperationCanceledException(
                    "The source model ``
                    if (readonly) then "read" else "write"
                    `` lock of project ``
                    name 
                    `` could not be acquired within ``
                    waitForModelInSeconds`` seconds");
            }
        } catch(InterruptedException ie) {
            throw platformUtils.newOperationCanceledException(
                "The thread was interrupted while waiting for the source model ``
                if (readonly) then "read" else "write"
                `` lock of project ``name``");
        } catch(Exception e) {
            if (is RuntimeException e) {
                throw e;
            } else {
                throw RuntimeException(e);
            }
        }
    }
}

shared abstract class CeylonProject<NativeProject, NativeResource, NativeFolder, NativeFile>()
        extends BaseCeylonProject()
        satisfies ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    shared actual formal CeylonProjectsAlias model;
    shared formal NativeProject ideArtifact;
    
    shared actual abstract class Modules() 
            extends super.Modules() 
            satisfies {IdeModuleAlias*} {
        shared formal TypecheckerModules typecheckerModules;
        
        shared actual Iterator<IdeModuleAlias> iterator() => object satisfies Iterator<IdeModuleAlias> {
            value it = typecheckerModules.listOfModules.iterator();
            shared actual IdeModuleAlias|Finished next() {
                if (it.hasNext()) {
                    assert(is BaseIdeModule m=it.next());
                    return unsafeCast<IdeModuleAlias>(m);
                } else {
                    return finished;
                }
            }
        };
        
        shared actual IdeModuleAlias default {
            assert(is IdeModule<NativeProject, NativeResource, NativeFolder, NativeFile> m=typecheckerModules.defaultModule);
            return m;
        }
        
        shared actual IdeModuleAlias language {
            assert(is IdeModule<NativeProject, NativeResource, NativeFolder, NativeFile> m=typecheckerModules.languageModule);
            return m; 
        }
        
        shared actual Package? javaLangPackage =>
                find((m) => m.nameAsString == "java.base")
                    ?.getDirectPackage("java.lang");
        
        shared actual {IdeModuleAlias*} fromProject
                => filter((m) => m.isProjectModule);
        
        shared actual {IdeModuleAlias*} external
                => filter((m) => ! m.isProjectModule);
        
        shared actual IdeModuleManagerAlias manager {
            assert(exists units=phasedUnits,
                    is IdeModuleManager<NativeProject, NativeResource, NativeFolder, NativeFile> mm=units.moduleManager);
            return mm; 
        }
        
        shared actual IdeModuleSourceMapperAlias sourceMapper {
            assert(exists units=phasedUnits,
                    is IdeModuleSourceMapper<NativeProject, NativeResource, NativeFolder, NativeFile> msm=units.moduleSourceMapper);
            return msm;
        }
    }
    
    shared actual Modules? modules =>
            if (exists tcMods = phasedUnits?.moduleManager?.modules)
            then 
                object extends Modules() {
                    typecheckerModules = tcMods;
                }
            else
                null;
    
    "Virtual folders of existing source folders as read form the IDE native project"
    shared actual {FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>*} sourceFolders =>
            sourceNativeFolders.map((nativeFolder) => model.vfs.createVirtualFolder(nativeFolder, ideArtifact));
    "Virtual folders of existing resource folders as read form the IDE native project"
    shared actual {FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>*} resourceFolders =>
            resourceNativeFolders.map((nativeFolder) => model.vfs.createVirtualFolder(nativeFolder, ideArtifact));

    "Existing source folders as read form the IDE native project"
    shared formal {NativeFolder*} sourceNativeFolders;
    "Existing resource folders as read form the IDE native project"
    shared formal {NativeFolder*} resourceNativeFolders;

    shared formal {NativeProject*} referencedNativeProjects(NativeProject nativeProject);
    shared formal {NativeProject*} referencingNativeProjects(NativeProject nativeProject);
    
    shared actual {CeylonProjectAlias*} referencedCeylonProjects =>
            referencedNativeProjects(ideArtifact)
            .map((NativeProject nativeProject) => model.getProject(nativeProject))
            .coalesced;

    shared actual {CeylonProjectAlias*} referencingCeylonProjects =>
            referencingNativeProjects(ideArtifact)
            .map((NativeProject nativeProject) => model.getProject(nativeProject))
            .coalesced;
    
    shared formal void setPackageForNativeFolder(NativeFolder folder, WeakReference<Package> p);
    shared formal void setRootForNativeFolder(NativeFolder folder, WeakReference<FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>> root);
    shared formal void setRootIsForSource(NativeFolder rootFolder, Boolean isSource);
    
    shared Boolean isCompilable(NativeFile file) {
        if (isCeylon(file)) {
            return true;
        }
        if (isJava(file) && compileToJava) {
            return true;
        }
        if (isJavascript(file) && compileToJs) {
            return true;
        }
        return false;
    }
    
    shared default Boolean isCeylon(NativeFile file) => 
            model.vfs.getShortName(file).endsWith(".ceylon");
    
    shared default Boolean isJava(NativeFile file) =>
            isJavaLikeFileName(model.vfs.getShortName(file));
    
    shared default Boolean isJavascript(NativeFile file) =>
            model.vfs.getShortName(file).endsWith(".js");
    
}

