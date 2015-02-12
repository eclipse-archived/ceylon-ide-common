import ceylon.collection {
    HashSet
}
import ceylon.file {
    File,
    parsePath,
    Path,
    Visitor,
    Directory,
    ExistingResource
}
import ceylon.interop.java {
    CeylonIterable
}
import ceylon.test {
    assertEquals,
    assertTrue,
    assertNotNull
}

import com.redhat.ceylon.ide.common.vfs {
    ResourceVirtualFile,
    FileVirtualFile,
    FolderVirtualFile
}

shared Directory resourcesRoot {
    assert (is Directory testResourcesDir = parsePath("test-resources").resource, 
        is Directory vfsDir = testResourcesDir.childResource("vfs"));
    return vfsDir;
}

shared abstract class BaseTest<NativeResource, NativeFolder, NativeFile>()
    given NativeResource satisfies Object
    given NativeFolder satisfies NativeResource
    given NativeFile satisfies NativeResource {

    shared alias ResourceVirtualFileAlias => ResourceVirtualFile<NativeResource,NativeFolder,NativeFile>;
    shared alias FolderVirtualFileAlias => FolderVirtualFile<NativeResource,NativeFolder,NativeFile>;
    shared alias FileVirtualFileAlias => FileVirtualFile<NativeResource,NativeFolder,NativeFile>;
    
    shared formal Path rootCeylonPath;
    shared formal FolderVirtualFile<NativeResource, NativeFolder, NativeFile> rootVirtualFile;

    ExpectedType checkType<ExpectedType> (
        ResourceVirtualFileAlias virtualFile,
        ExistingResource ceylonResource)
        given ExpectedType satisfies ResourceVirtualFile<NativeResource, NativeFolder, NativeFile> {
        assertTrue(
                virtualFile is ExpectedType/*,
                "'`` ceylonResource ``' should be seen as a `` typeLiteral<ExpectedType>() ``"*/);
        assert(is ExpectedType virtualFile);
        return virtualFile;
    }
    
    void checkChildren(Directory ceylonResource, ResourceVirtualFileAlias virtualFile) {
        value ceylonChildren = HashSet { * ceylonResource.childPaths().map((p)=>p.elements.last?.trimTrailing('/'.equals)).coalesced };
        value virtualFileChildren = HashSet { * CeylonIterable(virtualFile.children).map((vf)=>vf.name) };
        assertEquals(virtualFileChildren, ceylonChildren,
            "Wrong virtual file children");
    }
    
    
    shared default String pathFromCeylonResource(File|Directory fileOrDir) 
        => fileOrDir.path.absolutePath.string;
    
    shared default String nameFromCeylonResource(File|Directory fileOrDir) 
        => fileOrDir.path.elements.last else "";
    
    
    shared void checkParent(ResourceVirtualFileAlias virtualFile, Directory? ceylonParent) {
        assertEquals(
            virtualFile.parent?.path, 
            if (exists ceylonParent) then pathFromCeylonResource(ceylonParent) else null);
    }
    
    ResourceVirtualFileAlias findChildVirtualFileByName(
        FolderVirtualFileAlias parentVirtualFile, String name) {
        value child = CeylonIterable(parentVirtualFile.children).find((f)=>f.name == name.trimTrailing('/'.equals));
        assertNotNull(child, "The virtual file ``parentVirtualFile `` should have a child name '``name``'");
        assert (exists child);
        return child;
    }
    
    
    shared void testResourceTree() {
        variable FolderVirtualFileAlias? parentVirtualFile = null;
        variable Directory? parentCeylonFile = null;
        rootCeylonPath.visit {
            object visitor extends Visitor() {
                function doCheck<Type>(Directory|File fileOrDir) 
                        given Type satisfies ResourceVirtualFile<NativeResource, NativeFolder, NativeFile> {
                    Type currentVirtualFile;
                    if (fileOrDir.path == rootCeylonPath, is Type root = rootVirtualFile) {
                        currentVirtualFile = root;
                        assertEquals(currentVirtualFile.path, pathFromCeylonResource(fileOrDir));
                    } else {
                        assert(exists name = fileOrDir.path.elements.last);
                        assert(exists existingParentVirtualFile = parentVirtualFile);
                        currentVirtualFile = checkType<Type>(
                            findChildVirtualFileByName(existingParentVirtualFile, name), 
                            fileOrDir);
                        assertEquals(currentVirtualFile.path, pathFromCeylonResource(fileOrDir));
                        assertEquals(currentVirtualFile.name, nameFromCeylonResource(fileOrDir));
                        checkParent(currentVirtualFile, parentCeylonFile);
                    }
                    switch (fileOrDir)
                    case(is File) {
                        assertEquals(currentVirtualFile.folder, false);
                    }
                    case(is Directory) {
                        assertEquals(currentVirtualFile.folder, true);
                        checkChildren(fileOrDir, currentVirtualFile);
                    }
                    return currentVirtualFile;
                }
                
                shared actual Boolean beforeDirectory(Directory dir) {
                    parentVirtualFile = doCheck<FolderVirtualFile<NativeResource, NativeFolder, NativeFile>>(dir);
                    
                    parentCeylonFile = dir;
                    return true;
                }
                
                shared actual void file(File file) {
                    doCheck<FileVirtualFile<NativeResource, NativeFolder, NativeFile>>(file);
                }
                
                shared actual Boolean afterDirectory(Directory dir) {
                    parentCeylonFile = if (dir.path == rootCeylonPath)
                                            then null
                                            else if (is Directory dirParent = dir.path.parent.resource) 
                                                then dirParent 
                                                else null;
                    parentVirtualFile = parentVirtualFile?.parent;
                    return true;
                }
            }
        };
    }
}