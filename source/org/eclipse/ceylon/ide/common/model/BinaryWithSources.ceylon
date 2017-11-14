/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
shared interface BinaryWithSources
    satisfies SourceAware {
    shared formal String binaryRelativePath;

    shared String? computeFullPath(String? relativePath) =>
            if (exists archivePath = ceylonModule.sourceArchivePath,
                exists relativePath)
            then "``archivePath``!/``relativePath``"
            else null;
    
    shared actual default String? sourceFileName =>
            sourceRelativePath?.split('/'.equals)?.last;
    
    shared actual default String? sourceRelativePath =>
            ceylonModule.toSourceUnitRelativePath(binaryRelativePath);
    
    shared actual default String? sourceFullPath => 
            computeFullPath(sourceRelativePath);
}