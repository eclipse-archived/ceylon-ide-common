/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.ide.common.platform {
    CommonDocument
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}

shared interface CommonCompletionProposal {
    
    shared formal String withoutDupeSemi(CommonDocument document);
    
    shared formal DefaultRegion getSelectionInternal(CommonDocument document);
    
    shared formal String completionMode;

    shared formal String prefix;
    shared formal Integer offset;
    shared Integer start => offset - prefix.size;

    shared formal String description;
    shared formal String text;
    shared formal variable Integer length;
    
    shared formal void replaceInDoc(CommonDocument doc, Integer start, Integer length, String newText);
}