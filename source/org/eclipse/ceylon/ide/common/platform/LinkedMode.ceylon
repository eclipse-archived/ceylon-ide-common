/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.ide.common.completion {
    ProposalsHolder
}

shared abstract class LinkedMode(CommonDocument document) {
    
    shared formal void addEditableRegion(
        Integer start,
        Integer length,
        Integer exitSeqNumber,
        ProposalsHolder proposals
    );

    shared formal void addEditableGroup(
        "[start, length, exitSeqNumber]"
        [Integer, Integer, Integer]+ positions
    );

    shared formal void install(
        Object owner,
        Integer exitSeqNumber,
        Integer exitPosition
    );
}

shared class NoopLinkedMode(CommonDocument document) extends LinkedMode(document) {
    
    addEditableRegion(Integer start, Integer length, Integer exitSeqNumber, ProposalsHolder proposals)
        => noop();
    
    addEditableGroup(Integer[3]+ positions) => noop();
    
    install(Object owner, Integer exitSeqNumber, Integer exitPosition) => noop();
}
