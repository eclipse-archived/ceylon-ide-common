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
    PhasedUnits,
    PhasedUnit
}
import com.redhat.ceylon.ide.common.util {
    Path,
    unsafeCast,
    platformUtils,
    toJavaStringList,
    BaseProgressMonitor,
    synchronize,
    ImmutableMapWrapper
}
import com.redhat.ceylon.ide.common.vfs {
    FolderVirtualFile,
    BaseFolderVirtualFile,
    BaseFileVirtualFile,
    FileVirtualFile
}
import com.redhat.ceylon.model.typechecker.model {
    TypecheckerModules=Modules,
    Package,
    Module
}

import java.io {
    File
}
import java.lang {
    InterruptedException,
    RuntimeException,
    IllegalStateException,
    ObjectArray
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
import ceylon.collection {
    ArrayList,
    MutableList,
    MutableMap
}
import ceylon.interop.java {
    CeylonIterable
}
import com.redhat.ceylon.ide.common.model.parsing {
    RootFolderScanner,
    ModulesScanner,
    ProjectFilesScanner
}
import ceylon.language {
    newMap=map
}

shared final class ProjectState
        of missing | parsing | parsed | typechecking | typechecked | compiled
        satisfies Comparable<ProjectState> {
    Integer ordinal;
    shared new missing {ordinal=0;}
    shared new parsing {ordinal=1;}
    shared new parsed {ordinal=2;}
    shared new typechecking {ordinal=3;}
    shared new typechecked {ordinal=4;}
    shared new compiled {ordinal=5;}
    compare(ProjectState other) => 
            ordinal <=> other.ordinal;
    equals(Object that) =>
            if (is ProjectState that)
    then ordinal==that.ordinal
    else false;
}

shared abstract class BaseCeylonProject() {
    shared String ceylonConfigFileProjectRelativePath = ".ceylon/config";
    variable CeylonProjectConfig? ceylonConfig = null;
    variable CeylonIdeConfig? ideConfig = null;
    shared ReadWriteLock sourceModelLock =  ReentrantReadWriteLock();
    Lock repositoryManagerLock = ReentrantLock();
    variable RepositoryManager? _repositoryManager = null;
    shared ModuleDependencies moduleDependencies = ModuleDependencies();
    
    "TODO: should not be shared. Will be made unshared when the
     using methods will have been implemented in Ceylon"
    shared variable ProjectState state = ProjectState.missing;
    
    shared Boolean parsing => state == ProjectState.parsing;
    shared Boolean parsed => state >= ProjectState.parsed;
    shared Boolean typechecking => state == ProjectState.typechecking;
    shared Boolean typechecked => state >= ProjectState.typechecked;
    shared Boolean compiled => state >= ProjectState.compiled;
    
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
    
    shared {PhasedUnit*} parsedUnits =>
            if (parsed,
                exists units=typechecker?.phasedUnits?.phasedUnits)
            then CeylonIterable(units)
            else {};
    
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
    
    shared default abstract class Modules() satisfies {BaseIdeModule*} {
        shared formal BaseIdeModule default;
        shared formal BaseIdeModule language;
        shared formal Package? javaLangPackage;        
        shared formal {BaseIdeModule*} fromProject;
        shared formal {BaseIdeModule*} external;
        
        shared default BaseIdeModuleManager manager {
            assert(exists units=typechecker?.phasedUnits,
                is BaseIdeModuleManager mm=units.moduleManager);
            return mm; 
        }
        
        shared default BaseIdeModuleSourceMapper sourceMapper {
            assert(exists units=typechecker?.phasedUnits,
                is BaseIdeModuleSourceMapper msm=units.moduleSourceMapper);
            return msm; 
        }
    }

    shared formal Modules? modules;

    shared default BaseIdeModelLoader? modelLoader => modules?.manager?.modelLoader;
    
    shared formal {BaseFolderVirtualFile*} sourceFolders;
    shared formal {BaseFolderVirtualFile*} resourceFolders;
    shared formal {BaseFolderVirtualFile*} rootFolders;
    shared formal {BaseFileVirtualFile*} projectFiles;
    
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
    shared MutableMap<NativeFile, FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>> projectFilesMap = 
            ImmutableMapWrapper<NativeFile, FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>>();

    value sourceFoldersMap = ImmutableMapWrapper<NativeFolder, FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>>();
    value resourceFoldersMap = ImmutableMapWrapper<NativeFolder, FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>>();

    shared actual formal CeylonProjectsAlias model;
    shared formal NativeProject ideArtifact;
    
    shared CeylonProjects<NativeProject,NativeResource,NativeFolder,NativeFile>.VirtualFileSystem vfs => model.vfs; 
    
    shared actual abstract class Modules() 
            extends super.Modules() 
            satisfies {IdeModuleAlias*} {
        shared formal TypecheckerModules typecheckerModules;
        
        shared actual Iterator<IdeModuleAlias> iterator() => 
                typecheckerModules.listOfModules
                .toArray(ObjectArray<Module>(typecheckerModules.listOfModules.size()))
                .array.map((m) => unsafeCast<IdeModuleAlias>(m)).iterator();
        
        shared actual IdeModuleAlias default =>
                unsafeCast<IdeModule<NativeProject, NativeResource, NativeFolder, NativeFile>>(typecheckerModules.defaultModule);
        
        shared actual IdeModuleAlias language =>
                unsafeCast<IdeModule<NativeProject, NativeResource, NativeFolder, NativeFile>>(typecheckerModules.languageModule);
        
        shared actual Package? javaLangPackage =>
                find((m) => m.nameAsString == "java.base")
                    ?.getDirectPackage("java.lang");
        
        shared actual {IdeModuleAlias*} fromProject
                => filter((m) => m.isProjectModule);
        
        shared actual {IdeModuleAlias*} external
                => filter((m) => ! m.isProjectModule);
        
        shared actual IdeModuleManagerAlias manager
                => unsafeCast<IdeModuleManager<NativeProject, NativeResource, NativeFolder, NativeFile>>(super.manager); 
        
        shared actual IdeModuleSourceMapperAlias sourceMapper
                => unsafeCast<IdeModuleSourceMapper<NativeProject, NativeResource, NativeFolder, NativeFile>>(super.sourceMapper); 
    }
    
    shared actual Modules? modules =>
            if (exists tcMods = typechecker?.phasedUnits?.moduleManager?.modules)
            then 
                object extends Modules() {
                    typecheckerModules = tcMods;
                }
            else
                null;
    
    "Virtual folders of existing source folders as read form the IDE native project"
    shared actual {FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>*} sourceFolders =>
            sourceFoldersMap.resetKeys(
                sourceNativeFolders, 
                (nativeFolder) => 
                        vfs.createVirtualFolder(nativeFolder, ideArtifact)).items;
    
    "Virtual folders of existing resource folders as read form the IDE native project"
    shared actual {FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>*} resourceFolders =>
            resourceFoldersMap.resetKeys(
                resourceNativeFolders, 
                (nativeFolder) => 
                        vfs.createVirtualFolder(nativeFolder, ideArtifact)).items;

    shared actual {FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>*} rootFolders => 
            sourceFolders.chain(resourceFolders);

    shared FolderVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>? rootFolderFromNative(NativeFolder folder) => 
            sourceFoldersMap[folder] else resourceFoldersMap[folder];
    
    shared actual {FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>*} projectFiles => projectFilesMap.items;

    shared FileVirtualFile<NativeProject, NativeResource, NativeFolder, NativeFile>? projectFileFromNative(NativeFile file) => 
            projectFilesMap[file];
    
    shared {NativeFile*} projectNativeFiles => 
            projectFilesMap.keys;

    shared void addFile(NativeFile file) {
        projectFilesMap.remove(file);  // TODO : why don't we keep the virtualFile if it is there ?
        projectFilesMap.put(file, vfs.createVirtualFile(file, ideArtifact));
        // TODO : add the delta element
    }
    
    shared void removeFile(NativeFile file) {
        projectFilesMap.remove(file);
        // TODO : add the delta element
    }
    
    shared void addFolder(NativeFolder folder, NativeFolder parent) {
        value parentVirtualFile = vfs.createVirtualFolder(parent, ideArtifact);
        if (exists parentPkg = parentVirtualFile.ceylonPackage, 
            exists root=parentVirtualFile.rootFolder,
            exists loader = modelLoader) {
            Package pkg = loader.findOrCreatePackage(parentPkg.\imodule, 
                if (parentPkg.nameAsString.empty) 
                then vfs.getShortName(folder) 
                else ".".join {parentPkg.nameAsString, vfs.getShortName(folder)});
            setPackageForNativeFolder(folder, WeakReference(pkg));
            setRootForNativeFolder(folder, WeakReference(root));
        }

        // TODO : add the delta element
    }

    "Existing source folders as read form the IDE native project"
    shared formal {NativeFolder*} sourceNativeFolders;
    "Existing resource folders as read form the IDE native project"
    shared formal {NativeFolder*} resourceNativeFolders;

    shared {NativeFolder*} rootNativeFolders =>
            sourceNativeFolders.chain(resourceNativeFolders);

    
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
    shared formal void scanRootFolder(RootFolderScanner<NativeProject, NativeResource, NativeFolder, NativeFile> scanner);
    
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
            vfs.getShortName(file).endsWith(".ceylon");
    
    shared default Boolean isJava(NativeFile file) =>
            isJavaLikeFileName(vfs.getShortName(file));
    
    shared default Boolean isJavascript(NativeFile file) =>
            vfs.getShortName(file).endsWith(".js");
    
    "TODO: make it unshared as soon as the calling method is also in CeylonProject"
    shared void scanFiles(BaseProgressMonitor mon) {
        value monitor = mon.convert(10000);
        
        void scan(
            {FolderVirtualFile<NativeProject,NativeResource,NativeFolder,NativeFile>*} roots,
            RootFolderScanner<NativeProject, NativeResource, NativeFolder, NativeFile> scanner(FolderVirtualFile<NativeProject,NativeResource,NativeFolder,NativeFile> root)
        ) {
            for (root in roots) {
                if (monitor.cancelled) {
                    throw platformUtils.newOperationCanceledException("");
                }
                scanRootFolder(scanner(root));
            }
        }
        
        // First scan all non-default source modules and attach the contained packages 
        scan (sourceFolders, (root) => 
            ModulesScanner<NativeProject, NativeResource, NativeFolder, NativeFile>(this, root, monitor));
        
        // Then scan all source files
        scan (sourceFolders, (root) => 
            ProjectFilesScanner<NativeProject, NativeResource, NativeFolder, NativeFile>(this, root, true, projectFilesMap, monitor));
        
        // Finally scan all resource files
        scan (resourceFolders, (root) => 
            ProjectFilesScanner<NativeProject, NativeResource, NativeFolder, NativeFile>(this, root, false, projectFilesMap, monitor));
    }

}

