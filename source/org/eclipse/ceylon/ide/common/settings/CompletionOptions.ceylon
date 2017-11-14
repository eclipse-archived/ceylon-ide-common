/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
shared class CompletionOptions() {
    shared variable Boolean parameterTypesInCompletion = true;
    shared variable String inexactMatches = "positional";
    shared variable String completionMode = "insert";
    shared variable Boolean linkedModeArguments = true;
    shared variable Boolean chainLinkedModeArguments = false;
    shared variable Boolean enableCompletionFilters = false;
}