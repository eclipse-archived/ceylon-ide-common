import java.io {
    File
}

shared abstract class CeylonProject<IdeArtifact>()
        given IdeArtifact satisfies Object {
    shared String ceylonConfigFileProjectRelativePath = ".ceylon/config";
    shared formal IdeArtifact ideArtifact;
    shared formal File rootDirectory;
    shared formal Boolean hasConfigFile;
    
    "Un-hide a previously hidden output folder in old Eclipse projects
     
     For other IDEs, do nothing"
    shared default void fixHiddenOutputFolder(String folderProjectRelativePath) => noop();
    shared formal void deleteOldOutputFolder(String folderProjectRelativePath);
    shared formal void createNewOutputFolder(String folderProjectRelativePath);
    shared formal void refreshConfigFile();
    
    variable CeylonProjectConfig<IdeArtifact>? ceylonConfig = null;
    
    shared CeylonProjectConfig<IdeArtifact> configuration {
        if (exists config = ceylonConfig) {
            return config;
        } else {
            value newConfig = CeylonProjectConfig<IdeArtifact>(this);
            ceylonConfig = newConfig;
            return newConfig;
        }
    }
}


/*
 shared class EclipseCeylonProject(ideArtifact) extends CeylonProject<IProject> {
    shared actual IProject ideArtifact;
    shared actual File rootDirectory => ideArtifact.location().toFile();
 
    shared actual Boolean hasConfigFile
        => ideArtifact.findMember(ceylonConfigFileProjectRelativePath) exists;
 
    shared actual void refreshConfigFile() {
        try {
            IResource? config = ideArtifact.findMember(ceylonConfigFileProjectRelativePath);
            
            if (exists config) {
                config.refreshLocal(IResource.\iDEPTH_ZERO, 
                    new NullProgressMonitor());
            }
            else {
                project.refreshLocal(IResource.\iDEPTH_INFINITE, 
                    new NullProgressMonitor());
            }
        }
        catch (CoreException e) {
            e.printStackTrace();
        }
    }
    
    shared actual void fixHiddenOutputFolder(String folderProjectRelativePath) {
        IFolder oldOutputRepoFolder = ideArtifact.getFolder(folderProjectRelativePath);
        if (oldOutputRepoFolder.\iexists() && oldOutputRepoFolder.isHidden()) {
            try {
                oldOutputRepoFolder.setHidden(false);
            } catch (CoreException e) {
                e.printStackTrace();
            }
        }
    }
 
    shared actual void createNewOutputFolder(String folderProjectRelativePath) {
        IFolder newOutputRepoFolder = 
                ideArtifact.getFolder(folderProjectRelativePath);
        try {
            newOutputRepoFolder.refreshLocal(IResource.\iDEPTH_ONE, 
                NullProgressMonitor());
        }
        catch (CoreException ce) {
            ce.printStackTrace();
        }
        if (!newOutputRepoFolder.\iexists()) {
            try {
                CoreUtility.createDerivedFolder(newOutputRepoFolder, true, true, null);
            } catch (CoreException e) {
                e.printStackTrace();
            }
        }
        CeylonEncodingSynchronizer.instance.refresh(ideArtifact, null);
    }
    
    shared actual void deleteOldOutputFolder(String folderProjectRelativePath) {
        IFolder oldOutputRepoFolder = ideArtifact.getFolder(folderProjectRelativePath);
        if( oldOutputRepoFolder.\iexists() ) {
            Boolean remove = MessageDialog.openQuestion(PlatformUI.getWorkbench().getActiveWorkbenchWindow().getShell(), 
                "Changing Ceylon output repository", 
                "The Ceylon output repository has changed. Do you want to remove the old output repository folder '" + 
                        oldOutputRepoFolder.getFullPath().toString() + "' and all its contents?");
            if (remove) {
                try {
                    oldOutputRepoFolder.delete(true, null);
                } catch (CoreException e) {
                    e.printStackTrace();
                }
            }
        }
        if (oldOutputRepoFolder.\iexists() && oldOutputRepoFolder.isDerived()) {
            try {
                oldOutputRepoFolder.setDerived(false, null);
            } catch (CoreException e) {
                e.printStackTrace();
            }
        }
    }
 }
