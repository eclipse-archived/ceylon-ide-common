/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.compiler.typechecker.io {
    ClosableVirtualFile,
    VFS,
    VirtualFile
}
import java.io {
    File
}
import java.util.zip {
    ZipFile
}
import java.lang {
    overloaded
}

shared class VirtualFileSystem() extends VFS() {

    overloaded
    shared actual LocalFolderVirtualFile|LocalFileVirtualFile getFromFile(File file) =>
            if (file.directory) 
                then LocalFolderVirtualFile(file) 
                else LocalFileVirtualFile(file);

    overloaded
    shared actual BaseFolderVirtualFile getFromZipFile(ZipFile zipFile) =>
            ZipFileVirtualFile(zipFile);

    overloaded
    shared actual ClosableVirtualFile&BaseFolderVirtualFile getFromZipFile(File zipFile) =>
            ZipFileVirtualFile(ZipFile(zipFile), true);
    
    shared actual ClosableVirtualFile? openAsContainer(VirtualFile virtualFile) =>
            switch(virtualFile)
            case(is ZipFileVirtualFile) virtualFile
            case(is LocalFileVirtualFile) getFromZipFile(virtualFile.file)
            else null;
}