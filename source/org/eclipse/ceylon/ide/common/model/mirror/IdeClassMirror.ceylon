/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.model.loader.mirror {
    ClassMirror
}

shared interface IdeClassMirror satisfies ClassMirror {
    shared formal String fileName;
    shared formal String fullPath;
    shared formal Boolean isBinary;
    shared formal Boolean isCeylon;    
}