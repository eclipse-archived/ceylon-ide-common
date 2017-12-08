import ceylon.collection {
    HashSet
}
import ceylon.file {
    File,
    Path,
    Visitor,
    Directory,
    ExistingResource
}
import ceylon.test {
    assertEquals,
    assertTrue
}

import org.eclipse.ceylon.ide.common.vfs {
    BaseResourceVirtualFile,
    BaseFolderVirtualFile,
    BaseFileVirtualFile
}

import test.org.eclipse.ceylon.ide.common.testUtils {
    resourcesRootForPackage
}

Directory resourcesRoot = resourcesRootForPackage(`package`);

shared abstract class BaseTest() {

    shared formal Path rootCeylonPath;
    shared formal BaseFolderVirtualFile rootVirtualFile;

    ExpectedType checkType<ExpectedType> (
        BaseResourceVirtualFile virtualFile,
        ExistingResource ceylonResource)
        given ExpectedType satisfies BaseResourceVirtualFile {
        assertTrue(
                virtualFile is ExpectedType/*,
                "'`` ceylonResource ``' should be seen as a `` typeLiteral<ExpectedType>() ``"*/);
        assert(is ExpectedType virtualFile);
        return virtualFile;
    }

    void checkChildren(Directory ceylonResource, BaseResourceVirtualFile virtualFile) {
        value ceylonChildren
                = HashSet {
                    for (p in ceylonResource.childPaths())
                    if (exists last=p.elements.last)
                    last.trimTrailing('/'.equals)
                };
        value virtualFileChildren
                = HashSet {
                    for (vf in virtualFile.children)
                    vf.name
                };
        assertEquals(virtualFileChildren, ceylonChildren,
            "Wrong virtual file children");
    }


    shared default String pathFromCeylonResource(File|Directory fileOrDir)
        => fileOrDir.path.absolutePath.string;

    shared default String nameFromCeylonResource(File|Directory fileOrDir)
        => fileOrDir.path.elements.last else "";


    shared void checkParent(BaseResourceVirtualFile virtualFile, Directory? ceylonParent) {
        assertEquals(
            virtualFile.parent?.path,
            if (exists ceylonParent) then pathFromCeylonResource(ceylonParent) else null);
    }

    BaseResourceVirtualFile findChildVirtualFileByName(
        BaseFolderVirtualFile parentVirtualFile, String name) {
        for (child in parentVirtualFile.children) {
            if (child.name == name.trimTrailing('/'.equals)) {
                return child;
            }
        }
        throw AssertionError("The virtual file ``parentVirtualFile `` should have a child named '``name``'");
    }


    shared void testResourceTree() {
        variable BaseFolderVirtualFile? parentVirtualFile = null;
        variable Directory? parentCeylonFile = null;
        rootCeylonPath.visit {
            object visitor extends Visitor() {
                function doCheck<Type>(Directory|File fileOrDir)
                        given Type satisfies BaseResourceVirtualFile {
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
                    parentVirtualFile = doCheck<BaseFolderVirtualFile>(dir);

                    parentCeylonFile = dir;
                    return true;
                }

                shared actual void file(File file) {
                    doCheck<BaseFileVirtualFile>(file);
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