/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
shared class DefaultRegion(start, length=0) {
    shared Integer start;
    shared Integer length;
    shared Integer end => start + length;

    string => "[``start``-``length``]";
}

shared interface ExtractLinkedModeEnabled<Region=DefaultRegion> {
    shared formal variable Region? typeRegion;
    shared formal variable Region? decRegion;
    shared formal variable Region? refRegion;

    shared formal Region newRegion(Integer start, Integer length);

    shared formal [String+] nameProposals;
    
}
